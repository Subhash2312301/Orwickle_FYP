// Verification housekeeping: an account or listing whose reviewer asked for more evidence expires
// when the user has not answered within EXPIRE_AFTER_DAYS. The user can still update and resubmit.
// Runs when the server starts and then every hour.

const { pool } = require('../db/pool');
const { audit } = require('./audit');

const EXPIRE_AFTER_DAYS = 30;
const HOUR = 60 * 60 * 1000;

async function expireOverdue(db = pool) {
  const { rows: users } = await db.query(
    `UPDATE profiles SET review_status = 'expired'
      WHERE review_status = 'needs_evidence' AND reviewed_at < now() - make_interval(days => $1)
      RETURNING user_id`,
    [EXPIRE_AFTER_DAYS]);
  const { rows: listings } = await db.query(
    `UPDATE listings SET review_status = 'expired'
      WHERE review_status = 'needs_evidence' AND reviewed_at < now() - make_interval(days => $1)
      RETURNING id`,
    [EXPIRE_AFTER_DAYS]);
  for (const u of users) await audit(db, { action: 'verification.expired', entityId: u.user_id });
  for (const l of listings) await audit(db, { action: 'verification.expired', entityType: 'listing', entityId: l.id });
  return { users: users.length, listings: listings.length };
}

function scheduleExpiry() {
  const run = () => expireOverdue().catch(err => console.error('Verification expiry failed:', err.message));
  run();
  setInterval(run, HOUR).unref();
}

module.exports = { expireOverdue, scheduleExpiry, EXPIRE_AFTER_DAYS };
