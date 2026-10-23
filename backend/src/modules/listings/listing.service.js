// Business rules for project listings (Feature 2).
// The public preview (listings) and confidential details (listing_confidential) are read and
// returned separately, so a preview response can never contain confidential fields.

const crypto = require('node:crypto');
const { pool, withTransaction } = require('../../db/pool');
const HttpError = require('../../utils/httpError');
const { audit } = require('../../services/audit');
const storage = require('../../services/storage');

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const notFound = () => new HttpError(404, 'NOT_FOUND', 'Listing not found');

const PREVIEW_SELECT = `
  SELECT l.*, c.name AS category_name, p.full_name AS owner_name, p.avatar_path AS owner_avatar_path
    FROM listings l
    JOIN categories c ON c.id = l.category_id
    JOIN profiles p ON p.user_id = l.owner_id`;

async function toPreview(row, baseUrl) {
  return {
    id: row.id,
    listingType: row.listing_type,
    category: { id: row.category_id, name: row.category_name },
    title: row.title,
    shortDescription: row.short_description,
    techStack: row.tech_stack,
    projectStage: row.project_stage,
    askingAmount: row.asking_amount == null ? null : Number(row.asking_amount),
    currency: row.currency,
    coverUrl: await storage.signedUrl(row.thumbnail_path, baseUrl),
    status: row.status,
    reviewStatus: row.review_status,
    publishedAt: row.published_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    owner: {
      id: row.owner_id,
      fullName: row.owner_name,
      avatarUrl: await storage.signedUrl(row.owner_avatar_path, baseUrl),
    },
  };
}

function toConfidential(row) {
  return {
    fullDescription: row.full_description,
    problemStatement: row.problem_statement,
    solutionDetails: row.solution_details,
    businessModel: row.business_model,
    traction: row.traction,
    financialSummary: row.financial_summary,
    roadmap: row.roadmap,
    teamDetails: row.team_details,
    ipOwnershipNotes: row.ip_ownership_notes,
    equityOfferedPercent: row.equity_offered_percent == null ? null : Number(row.equity_offered_percent),
    transferDetails: row.transfer_details,
  };
}

// Loads a listing the user owns (for changes); other people's listings look like they do not exist.
async function loadOwned(db, listingId, ownerId) {
  if (!UUID.test(listingId)) throw notFound();
  const { rows: [row] } = await db.query(
    'SELECT * FROM listings WHERE id = $1 AND owner_id = $2 FOR UPDATE', [listingId, ownerId]);
  if (!row) throw notFound();
  return row;
}

function assertEditable(row) {
  if (row.status === 'suspended') {
    throw new HttpError(409, 'LISTING_SUSPENDED', 'This listing was suspended by an administrator and cannot be changed');
  }
  if (row.status === 'closed') throw new HttpError(409, 'LISTING_CLOSED', 'This listing is closed');
}

async function assertCategory(db, categoryId) {
  const { rowCount } = await db.query('SELECT 1 FROM categories WHERE id = $1 AND is_active', [categoryId]);
  if (!rowCount) {
    throw new HttpError(400, 'VALIDATION_ERROR', 'Please correct the highlighted fields',
      { categoryId: 'This category no longer exists' });
  }
}

const confidentialValues = c => [
  c.fullDescription, c.problemStatement, c.solutionDetails, c.businessModel, c.traction,
  c.financialSummary, c.roadmap, c.teamDetails, c.ipOwnershipNotes, c.equityOfferedPercent ?? null,
  c.transferDetails,
];

// ---------- reading ----------

async function getListing(listingId, user, baseUrl) {
  if (!UUID.test(listingId)) throw notFound();
  const { rows: [row] } = await pool.query(`${PREVIEW_SELECT} WHERE l.id = $1`, [listingId]);
  if (!row) throw notFound();

  const canSeeAll = row.owner_id === user.id || user.role === 'admin';
  if (!canSeeAll && row.status !== 'published') throw notFound();

  const result = { listing: await toPreview(row, baseUrl) };
  if (canSeeAll) {
    const { rows: [c] } = await pool.query('SELECT * FROM listing_confidential WHERE listing_id = $1', [listingId]);
    result.confidential = c ? toConfidential(c) : null;
  }
  return result;
}

async function listMine(ownerId, baseUrl) {
  const { rows } = await pool.query(`${PREVIEW_SELECT} WHERE l.owner_id = $1 ORDER BY l.updated_at DESC`, [ownerId]);
  return { listings: await Promise.all(rows.map(r => toPreview(r, baseUrl))) };
}

// ---------- changes (owner only) ----------

async function createListing(ownerId, body, { ip, baseUrl }) {
  const id = await withTransaction(async client => {
    await assertCategory(client, body.categoryId);
    const { rows: [listing] } = await client.query(
      `INSERT INTO listings (owner_id, listing_type, category_id, title, short_description, tech_stack,
                             project_stage, asking_amount, currency)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING id`,
      [ownerId, body.listingType, body.categoryId, body.title, body.shortDescription, body.techStack,
        body.projectStage, body.askingAmount, body.currency]);
    await client.query(
      `INSERT INTO listing_confidential (listing_id, full_description, problem_statement, solution_details,
         business_model, traction, financial_summary, roadmap, team_details, ip_ownership_notes,
         equity_offered_percent, transfer_details)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
      [listing.id, ...confidentialValues(body.confidential)]);
    await audit(client, { actorId: ownerId, action: 'listing.created', entityType: 'listing', entityId: listing.id, ip });
    return listing.id;
  });
  return getListing(id, { id: ownerId, role: 'owner' }, baseUrl);
}

// Saves the whole listing. Editing a published listing sends it back for review.
async function updateListing(listingId, ownerId, body, { ip, baseUrl }) {
  await withTransaction(async client => {
    const row = await loadOwned(client, listingId, ownerId);
    assertEditable(row);
    if (row.listing_type !== body.listingType && row.status !== 'draft') {
      throw new HttpError(400, 'VALIDATION_ERROR', 'Please correct the highlighted fields',
        { listingType: 'The listing type can only be changed while the listing is a draft' });
    }
    await assertCategory(client, body.categoryId);
    await client.query(
      `UPDATE listings
          SET listing_type = $2, category_id = $3, title = $4, short_description = $5, tech_stack = $6,
              project_stage = $7, asking_amount = $8, currency = $9,
              review_status = CASE WHEN status = 'published' THEN 'pending'::review_status ELSE review_status END
        WHERE id = $1`,
      [listingId, body.listingType, body.categoryId, body.title, body.shortDescription, body.techStack,
        body.projectStage, body.askingAmount, body.currency]);
    await client.query(
      `UPDATE listing_confidential
          SET full_description = $2, problem_statement = $3, solution_details = $4, business_model = $5,
              traction = $6, financial_summary = $7, roadmap = $8, team_details = $9, ip_ownership_notes = $10,
              equity_offered_percent = $11, transfer_details = $12
        WHERE listing_id = $1`,
      [listingId, ...confidentialValues(body.confidential)]);
    await audit(client, { actorId: ownerId, action: 'listing.updated', entityType: 'listing', entityId: listingId, ip });
  });
  return getListing(listingId, { id: ownerId, role: 'owner' }, baseUrl);
}

// Allowed status moves: draft → published (review pending), published → draft, draft/published → closed.
const TRANSITIONS = {
  publish: { from: ['draft'], to: 'published', done: 'published', set: ", published_at = now(), review_status = 'pending'" },
  unpublish: { from: ['published'], to: 'draft', done: 'unpublished', set: '' },
  close: { from: ['draft', 'published'], to: 'closed', done: 'closed', set: ', closed_at = now()' },
};

async function changeStatus(listingId, ownerId, action, { ip, baseUrl }) {
  const t = TRANSITIONS[action];
  await withTransaction(async client => {
    const row = await loadOwned(client, listingId, ownerId);
    assertEditable(row);
    if (!t.from.includes(row.status)) {
      throw new HttpError(409, 'INVALID_STATUS', `A ${row.status} listing cannot be ${t.done}`);
    }
    await client.query(`UPDATE listings SET status = $2 ${t.set} WHERE id = $1`, [listingId, t.to]);
    await audit(client, { actorId: ownerId, action: `listing.${t.done}`, entityType: 'listing', entityId: listingId, ip });
  });
  return getListing(listingId, { id: ownerId, role: 'owner' }, baseUrl);
}

// Only drafts can be deleted; published listings are closed instead so their history stays.
async function deleteListing(listingId, ownerId, { ip }) {
  const coverPath = await withTransaction(async client => {
    const row = await loadOwned(client, listingId, ownerId);
    if (row.status !== 'draft') {
      throw new HttpError(409, 'INVALID_STATUS', 'Only draft listings can be deleted. Close the listing instead.');
    }
    await client.query('DELETE FROM listings WHERE id = $1', [listingId]);
    await audit(client, { actorId: ownerId, action: 'listing.deleted', entityType: 'listing', entityId: listingId, ip });
    return row.thumbnail_path;
  });
  await storage.remove(coverPath);
}

async function setCover(listingId, ownerId, image, { ip, baseUrl }) {
  const row = await loadOwned(pool, listingId, ownerId);
  assertEditable(row);
  const filePath = `listings/${listingId}/cover-${crypto.randomUUID()}.${image.ext}`;
  await storage.upload(filePath, image.buffer, image.contentType);
  await pool.query('UPDATE listings SET thumbnail_path = $2 WHERE id = $1', [listingId, filePath]);
  await storage.remove(row.thumbnail_path);
  await audit(pool, { actorId: ownerId, action: 'listing.cover_updated', entityType: 'listing', entityId: listingId, ip });
  return getListing(listingId, { id: ownerId, role: 'owner' }, baseUrl);
}

async function removeCover(listingId, ownerId, { ip, baseUrl }) {
  const row = await loadOwned(pool, listingId, ownerId);
  assertEditable(row);
  await pool.query('UPDATE listings SET thumbnail_path = NULL WHERE id = $1', [listingId]);
  await storage.remove(row.thumbnail_path);
  await audit(pool, { actorId: ownerId, action: 'listing.cover_removed', entityType: 'listing', entityId: listingId, ip });
  return getListing(listingId, { id: ownerId, role: 'owner' }, baseUrl);
}

module.exports = {
  getListing, listMine, createListing, updateListing, changeStatus, deleteListing, setCover, removeCover,
};
