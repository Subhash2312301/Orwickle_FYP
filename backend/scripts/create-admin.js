// Creates an administrator account (admins cannot sign up through the app).
// Usage: npm run create-admin -- --email admin@example.com --name "Faryal Zia" [--password "..."]
// Without --password a strong one-time password is generated and printed; change it after the first login.

const crypto = require('node:crypto');
const bcrypt = require('bcryptjs');
const { pool, withTransaction } = require('../src/db/pool');
const authConfig = require('../src/config/auth');
const { isCommonPassword } = require('../src/modules/auth/passwordPolicy');

function arg(name) {
  const i = process.argv.indexOf(`--${name}`);
  return i > 0 ? process.argv[i + 1] : undefined;
}

// 16 random characters plus one of each required class
const strongPassword = () => `${crypto.randomBytes(12).toString('base64url')}Aa7#`;

async function main() {
  const email = arg('email')?.trim().toLowerCase();
  const name = arg('name')?.trim();
  if (!email || !name) {
    throw new Error('Usage: npm run create-admin -- --email admin@example.com --name "Full Name"');
  }

  const chosen = arg('password');
  const password = chosen || strongPassword();
  if (chosen && isCommonPassword(chosen)) {
    console.warn('Warning: this password would be refused for normal users as too common. Change it soon.');
  }
  const hash = await bcrypt.hash(password, authConfig.bcryptRounds);

  await withTransaction(async client => {
    const existing = await client.query('SELECT id FROM users WHERE email = $1', [email]);
    if (existing.rowCount) throw new Error(`A user with ${email} already exists.`);
    const { rows: [admin] } = await client.query(
      `INSERT INTO users (email, password_hash, role, email_verified_at, terms_accepted_at)
       VALUES ($1, $2, 'admin', now(), now()) RETURNING id`,
      [email, hash]);
    await client.query(
      `INSERT INTO profiles (user_id, full_name, review_status, reviewed_at) VALUES ($1, $2, 'approved', now())`,
      [admin.id, name]);
    await client.query(
      `INSERT INTO audit_logs (actor_id, action, entity_type, entity_id) VALUES (NULL, 'admin.created', 'user', $1)`,
      [admin.id]);
  });

  console.log(`Admin created: ${email}`);
  if (!chosen) {
    console.log(`One-time password: ${password}`);
    console.log('Store it safely and change it after the first login.');
  }
}

main()
  .catch(err => {
    console.error(err.message);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
