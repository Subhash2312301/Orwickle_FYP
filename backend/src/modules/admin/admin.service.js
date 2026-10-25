// Admin review of accounts and listings. Every decision is stored in review_decisions
// (append-only, with the reviewer and the reason), written to the audit log and emailed to the user.

const { pool, withTransaction } = require('../../db/pool');
const HttpError = require('../../utils/httpError');
const { audit } = require('../../services/audit');
const { sendMail } = require('../../services/mailer');
const { reviewEmail } = require('../../services/emailTemplates');
const profileService = require('../profiles/profile.service');
const listingService = require('../listings/listing.service');

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const USER_STATUS = { approve: 'approved', reject: 'rejected', request_more: 'needs_evidence' };

// Email problems must not undo a decision that is already saved.
async function notify(to, mail) {
  try {
    await sendMail({ to, ...mail });
  } catch (err) {
    console.error('Review email failed:', err.message);
  }
}

// ---------- accounts ----------

async function listUserReviews(status, baseUrl) {
  const { rows } = await pool.query(
    `SELECT u.id, u.role, u.created_at
       FROM users u JOIN profiles p ON p.user_id = u.id
      WHERE u.role <> 'admin' AND p.review_status = $1
      ORDER BY coalesce(p.updated_at, u.created_at)`,
    [status]);
  const users = await Promise.all(rows.map(async r => ({
    id: r.id,
    registeredAt: r.created_at,
    ...(await profileService.getMyProfile(r.id, r.role, { baseUrl })).profile,
  })));
  return { users };
}

async function reviewUser(adminId, userId, { decision, reason, checklist = {} }, { ip }) {
  if (!UUID.test(userId)) throw new HttpError(404, 'NOT_FOUND', 'User not found');
  const user = await withTransaction(async client => {
    const { rows: [u] } = await client.query(
      `SELECT u.id, u.email, u.role, p.full_name, p.profile_completed_at
         FROM users u JOIN profiles p ON p.user_id = u.id
        WHERE u.id = $1 FOR UPDATE OF p`,
      [userId]);
    if (!u || u.role === 'admin') throw new HttpError(404, 'NOT_FOUND', 'User not found');
    if (!u.profile_completed_at) {
      throw new HttpError(409, 'PROFILE_INCOMPLETE', 'This user has not completed their profile yet');
    }
    await client.query(
      `UPDATE profiles SET review_status = $2, review_note = $3, reviewed_at = now() WHERE user_id = $1`,
      [userId, USER_STATUS[decision], decision === 'approve' ? null : reason]);
    await client.query(
      `INSERT INTO review_decisions (reviewer_id, subject_user_id, decision, reason, checklist)
       VALUES ($1, $2, $3, $4, $5)`,
      [adminId, userId, decision, reason ?? 'Approved', checklist]);
    await audit(client, { actorId: adminId, action: `admin.user_${USER_STATUS[decision]}`, entityId: userId, ip,
      details: { reason } });
    return u;
  });

  await notify(user.email, reviewEmail({ kind: 'account', decision, name: user.full_name, reason }));
  return { userId, reviewStatus: USER_STATUS[decision], reviewNote: decision === 'approve' ? null : reason };
}

// ---------- listings ----------

async function listListingReviews(status, admin, baseUrl) {
  const { rows } = await pool.query(
    `SELECT id FROM listings WHERE status = 'published' AND review_status = $1 ORDER BY published_at`,
    [status]);
  return { listings: await Promise.all(rows.map(r => listingService.getListing(r.id, admin, baseUrl))) };
}

async function reviewListing(admin, listingId, { decision, reason, checklist = {} }, { ip, baseUrl }) {
  if (!UUID.test(listingId)) throw new HttpError(404, 'NOT_FOUND', 'Listing not found');
  const listing = await withTransaction(async client => {
    const { rows: [l] } = await client.query(
      `SELECT l.id, l.title, l.status, u.email, p.full_name
         FROM listings l JOIN users u ON u.id = l.owner_id JOIN profiles p ON p.user_id = l.owner_id
        WHERE l.id = $1 FOR UPDATE OF l`,
      [listingId]);
    if (!l) throw new HttpError(404, 'NOT_FOUND', 'Listing not found');
    if (l.status !== 'published') {
      throw new HttpError(409, 'INVALID_STATUS', 'Only published listings can be reviewed');
    }
    // a rejected listing goes back to draft so the owner can fix it and publish again
    await client.query(
      decision === 'approve'
        ? `UPDATE listings SET review_status = 'approved', review_note = NULL, reviewed_at = now() WHERE id = $1`
        : `UPDATE listings SET review_status = 'rejected', review_note = $2, reviewed_at = now(), status = 'draft' WHERE id = $1`,
      decision === 'approve' ? [listingId] : [listingId, reason]);
    await client.query(
      `INSERT INTO review_decisions (reviewer_id, subject_listing_id, decision, reason, checklist)
       VALUES ($1, $2, $3, $4, $5)`,
      [admin.id, listingId, decision, reason ?? 'Approved', checklist]);
    await audit(client, { actorId: admin.id, action: `admin.listing_${decision === 'approve' ? 'approved' : 'rejected'}`,
      entityType: 'listing', entityId: listingId, ip, details: { reason } });
    return l;
  });

  await notify(listing.email, reviewEmail({ kind: 'listing', decision, name: listing.full_name, reason, title: listing.title }));
  return listingService.getListing(listingId, admin, baseUrl);
}

module.exports = { listUserReviews, reviewUser, listListingReviews, reviewListing };
