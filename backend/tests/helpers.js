// Shared helpers for API tests. Test accounts use @test.orwickle.dev and are removed by cleanup().

const bcrypt = require('bcryptjs');
const { withTransaction } = require('../src/db/pool');

const DOMAIN = '@test.orwickle.dev';
const TEST_PASSWORD = 'Orbit#Lane42';
let counter = 0;

// A verified user created straight in the database, for tests that do not exercise sign-up.
async function createVerifiedUser(role, fullName = `Test ${role}`) {
  const email = `${role}${Date.now()}${counter++}${DOMAIN}`;
  const hash = await bcrypt.hash(TEST_PASSWORD, 4);   // low cost: tests only
  await withTransaction(async client => {
    const { rows: [user] } = await client.query(
      `INSERT INTO users (email, password_hash, role, email_verified_at, terms_accepted_at)
       VALUES ($1, $2, $3, now(), now()) RETURNING id`,
      [email, hash, role]);
    await client.query('INSERT INTO profiles (user_id, full_name) VALUES ($1, $2)', [user.id, fullName]);
    if (role !== 'admin') await client.query(`INSERT INTO ${role}_profiles (user_id) VALUES ($1)`, [user.id]);
  });
  return { email, password: TEST_PASSWORD };
}

// audit_logs is append-only, so its guard trigger is paused inside one transaction to remove test rows
const cleanup = () => withTransaction(async client => {
  await client.query('ALTER TABLE audit_logs DISABLE TRIGGER audit_logs_immutable');
  await client.query(
    `DELETE FROM audit_logs WHERE entity_id IN (SELECT id FROM users WHERE email LIKE $1)
        OR entity_id IN (SELECT l.id FROM listings l JOIN users u ON u.id = l.owner_id WHERE u.email LIKE $1)
        OR actor_id IN (SELECT id FROM users WHERE email LIKE $1)`, [`%${DOMAIN}`]);
  await client.query('ALTER TABLE audit_logs ENABLE TRIGGER audit_logs_immutable');
  // listings keep their owner (no cascade), so they go first
  await client.query(
    `DELETE FROM listings WHERE owner_id IN (SELECT id FROM users WHERE email LIKE $1)`, [`%${DOMAIN}`]);
  await client.query('DELETE FROM users WHERE email LIKE $1', [`%${DOMAIN}`]);
});

module.exports = { DOMAIN, createVerifiedUser, cleanup };
