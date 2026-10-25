// Shared helpers for API tests. Test accounts use @test.orwickle.dev and are removed by cleanup().

const bcrypt = require('bcryptjs');
const { withTransaction } = require('../src/db/pool');

const DOMAIN = '@test.orwickle.dev';
const TEST_PASSWORD = 'Orbit#Lane42';
let counter = 0;

// A verified user created straight in the database, for tests that do not exercise sign-up.
// approved: the account is already approved by an admin (profile completed).
async function createVerifiedUser(role, fullName = `Test ${role}`, { approved = false } = {}) {
  const email = `${role}${Date.now()}${counter++}${DOMAIN}`;
  const hash = await bcrypt.hash(TEST_PASSWORD, 4);   // low cost: tests only
  await withTransaction(async client => {
    const { rows: [user] } = await client.query(
      `INSERT INTO users (email, password_hash, role, email_verified_at, terms_accepted_at)
       VALUES ($1, $2, $3, now(), now()) RETURNING id`,
      [email, hash, role]);
    await client.query(
      `INSERT INTO profiles (user_id, full_name, review_status, profile_completed_at)
       VALUES ($1, $2, $3, $4)`,
      [user.id, fullName, approved || role === 'admin' ? 'approved' : 'unreviewed', approved ? new Date() : null]);
    if (role !== 'admin') await client.query(`INSERT INTO ${role}_profiles (user_id) VALUES ($1)`, [user.id]);
  });
  return { email, password: TEST_PASSWORD };
}

// audit_logs and review_decisions are append-only, so their guard triggers are paused inside
// one transaction to remove test rows
const cleanup = () => withTransaction(async client => {
  const testUsers = `SELECT id FROM users WHERE email LIKE $1`;
  const testListings = `SELECT l.id FROM listings l JOIN users u ON u.id = l.owner_id WHERE u.email LIKE $1`;
  const like = [`%${DOMAIN}`];

  await client.query('ALTER TABLE audit_logs DISABLE TRIGGER audit_logs_immutable');
  await client.query('ALTER TABLE review_decisions DISABLE TRIGGER review_decisions_immutable');
  await client.query(
    `DELETE FROM audit_logs WHERE entity_id IN (${testUsers}) OR entity_id IN (${testListings})
        OR actor_id IN (${testUsers})`, like);
  await client.query(
    `DELETE FROM review_decisions WHERE subject_user_id IN (${testUsers}) OR subject_listing_id IN (${testListings})
        OR reviewer_id IN (${testUsers})`, like);
  await client.query('ALTER TABLE review_decisions ENABLE TRIGGER review_decisions_immutable');
  await client.query('ALTER TABLE audit_logs ENABLE TRIGGER audit_logs_immutable');
  // uploaded documents and listings keep their user (no cascade), so they go first
  await client.query(
    `DELETE FROM evidence_submissions WHERE submitted_by IN (${testUsers}) OR subject_user_id IN (${testUsers})
        OR subject_listing_id IN (${testListings})`, like);
  await client.query(`DELETE FROM listings WHERE id IN (${testListings})`, like);
  await client.query(`DELETE FROM users WHERE id IN (${testUsers})`, like);
});

module.exports = { DOMAIN, createVerifiedUser, cleanup };
