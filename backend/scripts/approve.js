// Until the admin dashboard exists: approve an account and its listings waiting for review.
// Usage: npm run approve -- --email user@example.com [--reject "reason"] [--more "what is missing"]
// Uses the same rules as the admin API (decision record, audit log, email), acting as the first admin.

const { pool } = require('../src/db/pool');
const admin = require('../src/modules/admin/admin.service');

function arg(name) {
  const i = process.argv.indexOf(`--${name}`);
  return i > 0 ? process.argv[i + 1] : undefined;
}

async function main() {
  const email = arg('email')?.trim().toLowerCase();
  if (!email) throw new Error('Usage: npm run approve -- --email user@example.com [--reject "reason"] [--more "reason"]');

  const { rows: [reviewer] } = await pool.query(`SELECT id, role FROM users WHERE role = 'admin' ORDER BY created_at LIMIT 1`);
  if (!reviewer) throw new Error('Create an admin first: npm run create-admin');
  const { rows: [user] } = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
  if (!user) throw new Error(`No user with email ${email}`);

  const decision = arg('reject') ? 'reject' : arg('more') ? 'request_more' : 'approve';
  const reason = arg('reject') || arg('more') || null;
  const result = await admin.reviewUser(reviewer.id, user.id, { decision, reason }, { ip: null });
  console.log(`Account ${email}: ${result.reviewStatus}`);

  if (decision === 'approve') {
    const { rows } = await pool.query(
      `SELECT id, title FROM listings WHERE owner_id = $1 AND status = 'published' AND review_status = 'pending'`, [user.id]);
    for (const l of rows) {
      await admin.reviewListing(reviewer, l.id, { decision: 'approve', reason: null }, { ip: null, baseUrl: '' });
      console.log(`Listing approved: ${l.title}`);
    }
  }
}

main()
  .catch(err => {
    console.error(err.message);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
