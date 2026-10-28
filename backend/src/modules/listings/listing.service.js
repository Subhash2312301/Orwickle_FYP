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

const MAX_PHOTOS = 6;

// Pictures are part of the public preview, so changing them (like editing) sends a published listing back for review.
const BACK_TO_REVIEW = `review_status = CASE WHEN status = 'published' THEN 'pending'::review_status ELSE review_status END`;

const PREVIEW_SELECT = `
  SELECT l.*, c.name AS category_name, p.full_name AS owner_name, p.avatar_path AS owner_avatar_path,
         (SELECT coalesce(json_agg(json_build_object('id', ph.id, 'path', ph.path) ORDER BY ph.created_at), '[]')
            FROM listing_photos ph WHERE ph.listing_id = l.id) AS photos
    FROM listings l
    JOIN categories c ON c.id = l.category_id
    JOIN profiles p ON p.user_id = l.owner_id`;

// reviewNote (why an admin rejected the listing) is only for the owner and admins
async function toPreview(row, baseUrl, { withReviewNote = false } = {}) {
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
    photos: await Promise.all(row.photos.map(async ph => ({ id: ph.id, url: await storage.signedUrl(ph.path, baseUrl) }))),
    status: row.status,
    isSample: row.is_sample,   // demonstration data, shown with a "Sample" badge
    reviewStatus: row.review_status,
    ...(withReviewNote && { reviewNote: row.review_note }),
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
    businessModel: row.business_model,
    financialSummary: row.financial_summary,
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

async function assertOwnerApproved(db, ownerId) {
  const { rows: [p] } = await db.query('SELECT review_status FROM profiles WHERE user_id = $1', [ownerId]);
  if (p?.review_status !== 'approved') {
    throw new HttpError(403, 'ACCOUNT_NOT_APPROVED',
      'Your account is waiting for admin approval. You can publish once it is approved.');
  }
}

const confidentialValues = c => [
  c.fullDescription, c.problemStatement, c.businessModel, c.financialSummary, c.ipOwnershipNotes,
  c.equityOfferedPercent ?? null, c.transferDetails,
];

// ---------- reading ----------

async function getListing(listingId, user, baseUrl) {
  if (!UUID.test(listingId)) throw notFound();
  const { rows: [row] } = await pool.query(`${PREVIEW_SELECT} WHERE l.id = $1`, [listingId]);
  if (!row) throw notFound();

  const canSeeAll = row.owner_id === user.id || user.role === 'admin';
  // everyone else sees a listing only once it is published AND approved by an admin
  if (!canSeeAll && !(row.status === 'published' && row.review_status === 'approved')) throw notFound();

  const result = { listing: await toPreview(row, baseUrl, { withReviewNote: canSeeAll }) };
  if (canSeeAll) {
    const { rows: [c] } = await pool.query('SELECT * FROM listing_confidential WHERE listing_id = $1', [listingId]);
    result.confidential = c ? toConfidential(c) : null;
  }
  return result;
}

async function listMine(ownerId, baseUrl) {
  const { rows } = await pool.query(`${PREVIEW_SELECT} WHERE l.owner_id = $1 ORDER BY l.updated_at DESC`, [ownerId]);
  return { listings: await Promise.all(rows.map(r => toPreview(r, baseUrl, { withReviewNote: true }))) };
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
      `INSERT INTO listing_confidential (listing_id, full_description, problem_statement, business_model,
         financial_summary, ip_ownership_notes, equity_offered_percent, transfer_details)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
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
              ${BACK_TO_REVIEW}
        WHERE id = $1`,
      [listingId, body.listingType, body.categoryId, body.title, body.shortDescription, body.techStack,
        body.projectStage, body.askingAmount, body.currency]);
    await client.query(
      `UPDATE listing_confidential
          SET full_description = $2, problem_statement = $3, business_model = $4, financial_summary = $5,
              ip_ownership_notes = $6, equity_offered_percent = $7, transfer_details = $8
        WHERE listing_id = $1`,
      [listingId, ...confidentialValues(body.confidential)]);
    await audit(client, { actorId: ownerId, action: 'listing.updated', entityType: 'listing', entityId: listingId, ip });
  });
  return getListing(listingId, { id: ownerId, role: 'owner' }, baseUrl);
}

// Allowed status moves: draft → published (review pending), published → draft, draft/published → closed.
const TRANSITIONS = {
  publish: {
    from: ['draft'], to: 'published', done: 'published',
    set: ", published_at = now(), review_status = 'pending', review_note = NULL",
  },
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
    if (action === 'publish') await assertOwnerApproved(client, ownerId);
    await client.query(`UPDATE listings SET status = $2 ${t.set} WHERE id = $1`, [listingId, t.to]);
    await audit(client, { actorId: ownerId, action: `listing.${t.done}`, entityType: 'listing', entityId: listingId, ip });
  });
  return getListing(listingId, { id: ownerId, role: 'owner' }, baseUrl);
}

// Only drafts can be deleted; published listings are closed instead so their history stays.
async function deleteListing(listingId, ownerId, { ip }) {
  let filePaths;
  try {
    filePaths = await withTransaction(async client => {
      const row = await loadOwned(client, listingId, ownerId);
      if (row.status !== 'draft') {
        throw new HttpError(409, 'INVALID_STATUS', 'Only draft listings can be deleted. Close the listing instead.');
      }
      const { rows: photos } = await client.query('SELECT path FROM listing_photos WHERE listing_id = $1', [listingId]);
      await client.query('DELETE FROM listings WHERE id = $1', [listingId]);
      await audit(client, { actorId: ownerId, action: 'listing.deleted', entityType: 'listing', entityId: listingId, ip });
      return [row.thumbnail_path, ...photos.map(p => p.path)];
    });
  } catch (err) {
    // 23503 = foreign key violation: an admin review (or later an access request or offer) refers to the listing,
    // and that history is kept
    if (err.code === '23503') {
      throw new HttpError(409, 'LISTING_HAS_HISTORY',
        'This listing has already been reviewed or has activity, so its history is kept. Close it instead.');
    }
    throw err;
  }
  await Promise.all(filePaths.map(p => storage.remove(p)));
}

async function setCover(listingId, ownerId, image, { ip, baseUrl }) {
  const row = await loadOwned(pool, listingId, ownerId);
  assertEditable(row);
  const filePath = `listings/${listingId}/cover-${crypto.randomUUID()}.${image.ext}`;
  await storage.upload(filePath, image.buffer, image.contentType);
  await pool.query(`UPDATE listings SET thumbnail_path = $2, ${BACK_TO_REVIEW} WHERE id = $1`, [listingId, filePath]);
  await storage.remove(row.thumbnail_path);
  await audit(pool, { actorId: ownerId, action: 'listing.cover_updated', entityType: 'listing', entityId: listingId, ip });
  return getListing(listingId, { id: ownerId, role: 'owner' }, baseUrl);
}

async function removeCover(listingId, ownerId, { ip, baseUrl }) {
  const row = await loadOwned(pool, listingId, ownerId);
  assertEditable(row);
  await pool.query(`UPDATE listings SET thumbnail_path = NULL, ${BACK_TO_REVIEW} WHERE id = $1`, [listingId]);
  await storage.remove(row.thumbnail_path);
  await audit(pool, { actorId: ownerId, action: 'listing.cover_removed', entityType: 'listing', entityId: listingId, ip });
  return getListing(listingId, { id: ownerId, role: 'owner' }, baseUrl);
}

// Extra project photos (hardware, screenshots), at most MAX_PHOTOS per listing.
async function addPhoto(listingId, ownerId, image, { ip, baseUrl }) {
  await withTransaction(async client => {
    const row = await loadOwned(client, listingId, ownerId);
    assertEditable(row);
    const { rows: [{ count }] } = await client.query(
      'SELECT count(*)::int AS count FROM listing_photos WHERE listing_id = $1', [listingId]);
    if (count >= MAX_PHOTOS) {
      throw new HttpError(409, 'TOO_MANY_PHOTOS', `A listing can have at most ${MAX_PHOTOS} photos. Remove one first.`);
    }
    const filePath = `listings/${listingId}/photo-${crypto.randomUUID()}.${image.ext}`;
    await storage.upload(filePath, image.buffer, image.contentType);
    await client.query('INSERT INTO listing_photos (listing_id, path) VALUES ($1, $2)', [listingId, filePath]);
    await client.query(`UPDATE listings SET ${BACK_TO_REVIEW} WHERE id = $1`, [listingId]);
    await audit(client, { actorId: ownerId, action: 'listing.photo_added', entityType: 'listing', entityId: listingId, ip });
  });
  return getListing(listingId, { id: ownerId, role: 'owner' }, baseUrl);
}

async function removePhoto(listingId, photoId, ownerId, { ip, baseUrl }) {
  const filePath = await withTransaction(async client => {
    const row = await loadOwned(client, listingId, ownerId);
    assertEditable(row);
    const photoNotFound = new HttpError(404, 'NOT_FOUND', 'Photo not found');
    if (!UUID.test(photoId)) throw photoNotFound;
    const { rows: [photo] } = await client.query(
      'DELETE FROM listing_photos WHERE id = $1 AND listing_id = $2 RETURNING path', [photoId, listingId]);
    if (!photo) throw photoNotFound;
    await client.query(`UPDATE listings SET ${BACK_TO_REVIEW} WHERE id = $1`, [listingId]);
    await audit(client, { actorId: ownerId, action: 'listing.photo_removed', entityType: 'listing', entityId: listingId, ip });
    return photo.path;
  });
  await storage.remove(filePath);
  return getListing(listingId, { id: ownerId, role: 'owner' }, baseUrl);
}

module.exports = {
  getListing, listMine, createListing, updateListing, changeStatus, deleteListing, setCover, removeCover,
  addPhoto, removePhoto,
};
