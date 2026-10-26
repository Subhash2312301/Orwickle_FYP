// Admin review of accounts and listings. Every decision is stored in review_decisions
// (append-only, with the reviewer and the reason), written to the audit log and emailed to the user.

const { pool, withTransaction } = require('../../db/pool');
const HttpError = require('../../utils/httpError');
const { audit } = require('../../services/audit');
const { sendMail } = require('../../services/mailer');
const { reviewEmail } = require('../../services/emailTemplates');
const profileService = require('../profiles/profile.service');
const listingService = require('../listings/listing.service');
const { revokeAllSessions } = require('../auth/auth.service');

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

// ---------- overview ----------

async function stats() {
  const { rows: [u] } = await pool.query(
    `SELECT count(*) FILTER (WHERE u.role = 'owner')                             AS owners,
            count(*) FILTER (WHERE u.role = 'investor')                          AS investors,
            count(*) FILTER (WHERE u.role = 'buyer')                             AS buyers,
            count(*) FILTER (WHERE p.review_status = 'approved')                 AS approved,
            count(*) FILTER (WHERE p.review_status = 'pending')                  AS pending,
            count(*) FILTER (WHERE p.review_status IN ('unreviewed', 'rejected', 'needs_evidence')) AS not_approved,
            count(*) FILTER (WHERE u.email_verified_at IS NULL)                  AS unverified_email,
            count(*) FILTER (WHERE u.created_at >= date_trunc('day', now()))     AS new_today,
            count(*) FILTER (WHERE u.locked_until > now())                       AS locked,
            count(*) FILTER (WHERE u.status = 'suspended')                       AS suspended,
            count(*) FILTER (WHERE p.is_sample)                                  AS samples
       FROM users u JOIN profiles p ON p.user_id = u.id
      WHERE u.role <> 'admin'`);
  const { rows: [l] } = await pool.query(
    `SELECT count(*) FILTER (WHERE status = 'published' AND review_status = 'approved') AS live,
            count(*) FILTER (WHERE status = 'published' AND review_status = 'pending')  AS pending,
            count(*) FILTER (WHERE status = 'draft')                                    AS drafts,
            count(*) FILTER (WHERE status = 'closed')                                   AS closed,
            count(*) FILTER (WHERE listing_type = 'funding')                            AS funding,
            count(*) FILTER (WHERE listing_type = 'sale')                               AS sale
       FROM listings`);
  const num = row => Object.fromEntries(Object.entries(row).map(([k, v]) => [k.replace(/_(\w)/g, (_, c) => c.toUpperCase()), Number(v)]));
  return { users: num(u), listings: num(l) };
}

// ---------- users ----------

const USER_FILTERS = {
  role: v => ['owner', 'investor', 'buyer'].includes(v) && ['u.role = $', v],
  review: v => ['unreviewed', 'pending', 'approved', 'rejected', 'needs_evidence'].includes(v) && ['p.review_status = $', v],
  status: v => ['active', 'suspended'].includes(v) && ['u.status = $', v],
};

async function listUsers(query) {
  const where = ["u.role <> 'admin'"];
  const params = [];
  for (const [key, build] of Object.entries(USER_FILTERS)) {
    const condition = query[key] && build(query[key]);
    if (condition) {
      params.push(condition[1]);
      where.push(condition[0] + params.length);
    }
  }
  const search = typeof query.search === 'string' ? query.search.trim().slice(0, 100) : '';
  if (search) {
    params.push(`%${search}%`);
    where.push(`(u.email ILIKE $${params.length} OR p.full_name ILIKE $${params.length})`);
  }
  const { rows } = await pool.query(
    `SELECT u.id, u.email, u.role, u.status, u.created_at, u.email_verified_at, u.locked_until,
            p.full_name, p.review_status, p.is_sample
       FROM users u JOIN profiles p ON p.user_id = u.id
      WHERE ${where.join(' AND ')}
      ORDER BY u.created_at DESC
      LIMIT 200`,
    params);
  return {
    users: rows.map(r => ({
      id: r.id,
      email: r.email,
      role: r.role,
      fullName: r.full_name,
      status: r.status,
      reviewStatus: r.review_status,
      emailVerified: Boolean(r.email_verified_at),
      locked: Boolean(r.locked_until && r.locked_until > new Date()),
      isSample: r.is_sample,
      registeredAt: r.created_at,
    })),
  };
}

// Everything an admin needs to judge one account: profile, documents, listings and past decisions.
async function getUser(userId, admin, baseUrl) {
  if (!UUID.test(userId)) throw new HttpError(404, 'NOT_FOUND', 'User not found');
  const { rows: [u] } = await pool.query(
    `SELECT id, email, role, status, created_at, email_verified_at, locked_until FROM users WHERE id = $1`, [userId]);
  if (!u || u.role === 'admin') throw new HttpError(404, 'NOT_FOUND', 'User not found');
  const { profile } = await profileService.getMyProfile(u.id, u.role, { baseUrl });
  const { rows: decisions } = await pool.query(
    `SELECT d.decision, d.reason, d.checklist, d.created_at, p.full_name AS reviewer
       FROM review_decisions d LEFT JOIN profiles p ON p.user_id = d.reviewer_id
      WHERE d.subject_user_id = $1
      ORDER BY d.created_at DESC`,
    [userId]);
  const listings = u.role === 'owner' ? (await listingService.listMine(u.id, baseUrl)).listings : [];
  return {
    user: {
      id: u.id,
      email: u.email,
      role: u.role,
      status: u.status,
      emailVerified: Boolean(u.email_verified_at),
      locked: Boolean(u.locked_until && u.locked_until > new Date()),
      registeredAt: u.created_at,
    },
    profile,
    listings,
    decisions: decisions.map(d => ({
      decision: d.decision, reason: d.reason, checklist: d.checklist, reviewer: d.reviewer, at: d.created_at,
    })),
  };
}

// Suspending ends every session at once: the app is logged out at its next token refresh
// (within about 2 minutes) and the account cannot log in until it is reinstated.
async function setAccountStatus(adminId, userId, action, reason, { ip }) {
  if (!UUID.test(userId)) throw new HttpError(404, 'NOT_FOUND', 'User not found');
  const suspend = action === 'suspend';
  const user = await withTransaction(async client => {
    const { rows: [u] } = await client.query(
      `SELECT u.id, u.email, u.role, u.status, p.full_name
         FROM users u JOIN profiles p ON p.user_id = u.id WHERE u.id = $1 FOR UPDATE OF u`, [userId]);
    if (!u || u.role === 'admin') throw new HttpError(404, 'NOT_FOUND', 'User not found');
    if ((u.status === 'suspended') === suspend) {
      throw new HttpError(409, 'INVALID_STATUS', suspend ? 'This account is already suspended' : 'This account is not suspended');
    }
    await client.query('UPDATE users SET status = $2 WHERE id = $1', [userId, suspend ? 'suspended' : 'active']);
    if (suspend) await revokeAllSessions(client, userId);
    await client.query(
      `INSERT INTO review_decisions (reviewer_id, subject_user_id, decision, reason) VALUES ($1, $2, $3, $4)`,
      [adminId, userId, action, reason]);
    await audit(client, { actorId: adminId, action: `admin.user_${suspend ? 'suspended' : 'reinstated'}`, entityId: userId, ip,
      details: { reason } });
    return u;
  });
  await notify(user.email, reviewEmail({ kind: 'account', decision: action, name: user.full_name, reason }));
  return { userId, status: suspend ? 'suspended' : 'active' };
}

// ---------- audit log ----------

async function auditLog(query) {
  const limit = Math.min(Math.max(Number.parseInt(query.limit, 10) || 50, 1), 200);
  const params = [limit];
  let where = '';
  if (typeof query.action === 'string' && query.action.trim()) {
    params.push(`${query.action.trim().slice(0, 50)}%`);
    where = `WHERE a.action LIKE $${params.length}`;
  }
  const { rows } = await pool.query(
    `SELECT a.id, a.action, a.entity_type, a.entity_id, a.after, a.ip_address, a.created_at,
            u.email AS actor_email, u.role AS actor_role
       FROM audit_logs a LEFT JOIN users u ON u.id = a.actor_id
       ${where}
      ORDER BY a.id DESC
      LIMIT $1`,
    params);
  return {
    entries: rows.map(r => ({
      id: Number(r.id),
      action: r.action,
      entityType: r.entity_type,
      entityId: r.entity_id,
      details: r.after,
      ip: r.ip_address,
      actor: r.actor_email ? { email: r.actor_email, role: r.actor_role } : null,
      at: r.created_at,
    })),
  };
}

module.exports = {
  listUserReviews, reviewUser, listListingReviews, reviewListing,
  stats, listUsers, getUser, setAccountStatus, auditLog,
};
