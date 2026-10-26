// Reads and saves the logged-in user's profile: common fields, role details, category interests
// and verification documents (CNIC, university ID, company certificate).

const crypto = require('node:crypto');
const { pool, withTransaction } = require('../../db/pool');
const HttpError = require('../../utils/httpError');
const { audit } = require('../../services/audit');
const storage = require('../../services/storage');
const { requiredDocuments, DOCUMENT_LABELS, ALLOWED_DOCUMENTS } = require('./profile.validation');

const toNumber = v => (v == null ? null : Number(v));

async function loadInterests(db, userId) {
  const { rows } = await db.query(
    `SELECT c.id, c.name FROM user_category_interests i
       JOIN categories c ON c.id = i.category_id
      WHERE i.user_id = $1 ORDER BY c.sort_order, c.name`,
    [userId]);
  return rows;
}

// Uploaded verification documents with short-lived links (only the user and admins ever get these).
async function loadDocuments(db, userId, baseUrl) {
  const { rows } = await db.query(
    `SELECT kind, storage_path, content_type, created_at FROM evidence_submissions
      WHERE subject_user_id = $1 AND kind = ANY($2::text[]) ORDER BY created_at`,
    [userId, Object.keys(DOCUMENT_LABELS)]);
  return Promise.all(rows.map(async r => ({
    kind: r.kind,
    url: await storage.signedUrl(r.storage_path, baseUrl),
    contentType: r.content_type,
    uploadedAt: r.created_at,
  })));
}

async function getMyProfile(userId, role, { db = pool, baseUrl } = {}) {
  const { rows: [p] } = await db.query(
    `SELECT u.email, p.full_name, p.headline, p.bio, p.city, p.phone, p.linkedin_url, p.website_url, p.avatar_path,
            p.review_status, p.review_note, p.completed_deal_count, p.profile_completed_at, p.is_sample
       FROM users u JOIN profiles p ON p.user_id = u.id WHERE u.id = $1`,
    [userId]);
  if (!p) throw new HttpError(404, 'NOT_FOUND', 'Profile not found');

  const profile = {
    role,
    email: p.email,
    fullName: p.full_name,
    avatarUrl: await storage.signedUrl(p.avatar_path, baseUrl),
    headline: p.headline,
    bio: p.bio,
    city: p.city,
    phone: p.phone,
    linkedinUrl: p.linkedin_url,
    websiteUrl: p.website_url,
    // admin approval of the account; reviewNote explains a rejection or a request for more information
    reviewStatus: role === 'admin' ? 'approved' : p.review_status,
    reviewNote: p.review_note,
    completedDealCount: p.completed_deal_count,
    completed: role === 'admin' || Boolean(p.profile_completed_at),
    isSample: p.is_sample,
    details: null,
    documents: role === 'admin' ? [] : await loadDocuments(db, userId, baseUrl),
  };

  if (role === 'owner') {
    const { rows: [d] } = await db.query('SELECT * FROM owner_profiles WHERE user_id = $1', [userId]);
    profile.details = d && {
      isStudent: d.is_student,
      university: d.university,
      degreeProgram: d.degree_program,
      skills: d.skills,
      githubUrl: d.github_url,
      portfolioUrl: d.portfolio_url,
    };
  } else if (role === 'investor') {
    const { rows: [d] } = await db.query('SELECT * FROM investor_profiles WHERE user_id = $1', [userId]);
    profile.details = d && {
      investorType: d.investor_type,
      cnicNumber: d.cnic_number,
      companyName: d.organization_name,
      companyWebsite: d.company_website,
      companyEmail: d.company_email,
      investmentExperience: d.investment_experience,
      professionalAffiliation: d.professional_affiliation,
      investmentHistory: d.investment_history,
      portfolioUrl: d.portfolio_url,
      minTicket: toNumber(d.min_ticket),
      maxTicket: toNumber(d.max_ticket),
      interests: await loadInterests(db, userId),
    };
  } else if (role === 'buyer') {
    const { rows: [d] } = await db.query('SELECT * FROM buyer_profiles WHERE user_id = $1', [userId]);
    profile.details = d && {
      buyerType: d.buyer_type,
      affiliation: d.affiliation,
      companyName: d.company_name,
      companyEmail: d.company_email,
      interests: await loadInterests(db, userId),
    };
  }
  return { profile };
}

async function saveInterests(client, userId, categoryIds) {
  const ids = [...new Set(categoryIds)];
  const { rows } = await client.query(
    'SELECT id FROM categories WHERE id = ANY($1::uuid[]) AND is_active', [ids]);
  if (rows.length !== ids.length) {
    throw new HttpError(400, 'VALIDATION_ERROR', 'Please correct the highlighted fields',
      { 'details.interests': 'One of the chosen categories no longer exists' });
  }
  await client.query('DELETE FROM user_category_interests WHERE user_id = $1', [userId]);
  await client.query(
    `INSERT INTO user_category_interests (user_id, category_id) SELECT $1, unnest($2::uuid[])`,
    [userId, ids]);
}

async function assertDocuments(db, userId, role, details) {
  const needed = requiredDocuments(role, details);
  if (!needed.length) return;
  const { rows } = await db.query(
    'SELECT kind FROM evidence_submissions WHERE subject_user_id = $1 AND kind = ANY($2::text[])', [userId, needed]);
  const have = new Set(rows.map(r => r.kind));
  const missing = needed.filter(kind => !have.has(kind));
  if (missing.length) {
    throw new HttpError(400, 'VALIDATION_ERROR', 'Please upload the required documents',
      Object.fromEntries(missing.map(kind => [`documents.${kind}`, `Upload ${DOCUMENT_LABELS[kind]}`])));
  }
}

// Saves the whole profile; the first complete save marks the profile as completed and sends it for review.
async function updateMyProfile(userId, role, body, { ip, baseUrl }) {
  const d = body.details;
  return withTransaction(async client => {
    await assertDocuments(client, userId, role, d);

    // fields a role does not have are left untouched
    // ($8 owner: headline, bio; $9 owner/investor: website; $10 investor/buyer: phone)
    await client.query(
      `UPDATE profiles
          SET full_name = $2, city = $3,
              headline = CASE WHEN $8 THEN $4 ELSE headline END,
              bio = CASE WHEN $8 THEN $5 ELSE bio END,
              website_url = CASE WHEN $9 THEN $7 ELSE website_url END,
              linkedin_url = $6,
              phone = CASE WHEN $10 THEN $11 ELSE phone END,
              profile_completed_at = coalesce(profile_completed_at, now()),
              -- a first save, or a save after a rejection / request for more information, goes to the admin
              review_status = CASE WHEN review_status IN ('unreviewed', 'rejected', 'needs_evidence')
                                   THEN 'pending'::review_status ELSE review_status END
        WHERE user_id = $1`,
      [userId, body.fullName, body.city ?? null, body.headline ?? null, body.bio ?? null, body.linkedinUrl ?? null,
        body.websiteUrl ?? null, role === 'owner', role === 'owner' || role === 'investor',
        role === 'investor' || role === 'buyer', body.phone ?? null]);

    if (role === 'owner') {
      await client.query(
        `UPDATE owner_profiles
            SET is_student = $2, university = $3, degree_program = $4, skills = $5,
                github_url = $6, portfolio_url = $7
          WHERE user_id = $1`,
        [userId, d.isStudent, d.isStudent ? d.university : null, d.isStudent ? d.degreeProgram : null, d.skills,
          d.githubUrl, d.portfolioUrl]);
      await removeDocumentRows(client, userId,
        d.isStudent ? ['cnic_front', 'cnic_back'] : ['university_id_front', 'university_id_back']);
    } else if (role === 'investor') {
      await client.query(
        `UPDATE investor_profiles
            SET investor_type = $2, cnic_number = $3, organization_name = $4, company_website = $5,
                company_email = $6, investment_experience = $7, min_ticket = $8, max_ticket = $9,
                professional_affiliation = $10, investment_history = $11, portfolio_url = $12
          WHERE user_id = $1`,
        [userId, d.investorType, d.cnicNumber, d.companyName, d.companyWebsite, d.companyEmail,
          d.investmentExperience, d.minTicket, d.maxTicket, d.professionalAffiliation,
          d.investmentExperience === 'first_time' ? null : d.investmentHistory, d.portfolioUrl]);
      // e.g. a firm no longer needs proof of funds; a first-time investor has no past investment to prove
      const needed = requiredDocuments(role, d);
      await removeDocumentRows(client, userId,
        ['company_certificate', 'funds_proof', 'investment_proof'].filter(kind => !needed.includes(kind)));
      await saveInterests(client, userId, d.interests);
    } else if (role === 'buyer') {
      await client.query(
        `UPDATE buyer_profiles SET buyer_type = $2, affiliation = $3, company_name = $4, company_email = $5
          WHERE user_id = $1`,
        [userId, d.buyerType, d.affiliation, ...(d.affiliation === 'company' ? [d.companyName, d.companyEmail] : [null, null])]);
      if (d.affiliation === 'company') {
        await removeDocumentRows(client, userId, ['university_id_front', 'university_id_back']);
      }
      await saveInterests(client, userId, d.interests);
    }

    await audit(client, { actorId: userId, action: 'profile.updated', entityId: userId, ip });
    return getMyProfile(userId, role, { db: client, baseUrl });
  });
}

// ---------- verification documents ----------

// Deletes document rows (files are removed afterwards by the caller or left for cleanup).
async function removeDocumentRows(db, userId, kinds) {
  const { rows } = await db.query(
    `DELETE FROM evidence_submissions WHERE subject_user_id = $1 AND kind = ANY($2::text[]) RETURNING storage_path`,
    [userId, kinds]);
  await Promise.all(rows.map(r => storage.remove(r.storage_path)));
}

function assertKind(role, kind) {
  if (!(ALLOWED_DOCUMENTS[role] || []).includes(kind)) {
    throw new HttpError(400, 'VALIDATION_ERROR', 'This document is not needed for your role',
      { kind: 'This document is not needed for your role' });
  }
}

// Stores or replaces one document. Changing a document of an approved account sends it back to review.
async function setDocument(userId, role, kind, file, { ip, baseUrl }) {
  assertKind(role, kind);
  const filePath = `documents/${userId}/${kind}-${crypto.randomUUID()}.${file.ext}`;
  await storage.upload(filePath, file.buffer, file.contentType);

  const oldPath = await withTransaction(async client => {
    const { rows: [old] } = await client.query(
      'DELETE FROM evidence_submissions WHERE subject_user_id = $1 AND kind = $2 RETURNING storage_path', [userId, kind]);
    await client.query(
      `INSERT INTO evidence_submissions (submitted_by, subject_user_id, kind, storage_path, content_type)
       VALUES ($1, $1, $2, $3, $4)`,
      [userId, kind, filePath, file.contentType]);
    await client.query(
      `UPDATE profiles SET review_status = 'pending', review_note = NULL
        WHERE user_id = $1 AND review_status = 'approved'`, [userId]);
    await audit(client, { actorId: userId, action: 'profile.document_uploaded', entityId: userId, ip, details: { kind } });
    return old?.storage_path;
  });
  await storage.remove(oldPath);
  return getMyProfile(userId, role, { baseUrl });
}

async function removeDocument(userId, role, kind, { ip, baseUrl }) {
  assertKind(role, kind);
  await removeDocumentRows(pool, userId, [kind]);
  await audit(pool, { actorId: userId, action: 'profile.document_removed', entityId: userId, ip, details: { kind } });
  return getMyProfile(userId, role, { baseUrl });
}

// ---------- profile photo ----------

// Replaces the profile photo; the old file is deleted after the database points to the new one.
async function setAvatar(userId, role, image, { ip, baseUrl }) {
  const filePath = `avatars/${userId}/${crypto.randomUUID()}.${image.ext}`;
  await storage.upload(filePath, image.buffer, image.contentType);
  const { rows: [old] } = await pool.query('SELECT avatar_path FROM profiles WHERE user_id = $1', [userId]);
  await pool.query('UPDATE profiles SET avatar_path = $2 WHERE user_id = $1', [userId, filePath]);
  await storage.remove(old?.avatar_path);
  await audit(pool, { actorId: userId, action: 'profile.avatar_updated', entityId: userId, ip });
  return getMyProfile(userId, role, { baseUrl });
}

async function removeAvatar(userId, role, { ip, baseUrl }) {
  const { rows: [old] } = await pool.query('SELECT avatar_path FROM profiles WHERE user_id = $1', [userId]);
  await pool.query('UPDATE profiles SET avatar_path = NULL WHERE user_id = $1', [userId]);
  await storage.remove(old?.avatar_path);
  await audit(pool, { actorId: userId, action: 'profile.avatar_removed', entityId: userId, ip });
  return getMyProfile(userId, role, { baseUrl });
}

async function listCategories() {
  const { rows } = await pool.query(
    'SELECT id, name, slug FROM categories WHERE is_active ORDER BY sort_order, name');
  return { categories: rows };
}

module.exports = {
  getMyProfile, updateMyProfile, setDocument, removeDocument, setAvatar, removeAvatar, listCategories,
};
