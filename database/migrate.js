// Applies database/migrations/*.sql and then database/seeds/*.sql in file-name order.
// Each file runs once, inside a transaction, and is recorded in schema_migrations.
// Usage: npm run migrate          (reads DATABASE_URL from database/.env)
//        npm run migrate:status   (lists applied and pending files)

const fs = require('node:fs');
const path = require('node:path');
const { Client } = require('pg');

const DIRS = ['migrations', 'seeds'];

function pendingFiles() {
  return DIRS.flatMap(dir =>
    fs.readdirSync(path.join(__dirname, dir))
      .filter(f => f.endsWith('.sql'))
      .sort()
      .map(f => `${dir}/${f}`));
}

async function main() {
  if (!process.env.DATABASE_URL) {
    throw new Error('DATABASE_URL is not set. Copy .env.example to .env and fill it in.');
  }
  const statusOnly = process.argv.includes('--status');
  const client = new Client({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false },   // Supabase uses its own CA
  });
  await client.connect();

  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        file        text PRIMARY KEY,
        applied_at  timestamptz NOT NULL DEFAULT now()
      );
      ALTER TABLE schema_migrations ENABLE ROW LEVEL SECURITY;`);

    const { rows } = await client.query('SELECT file FROM schema_migrations');
    const applied = new Set(rows.map(r => r.file));

    for (const file of pendingFiles()) {
      if (applied.has(file)) {
        if (statusOnly) console.log(`  applied  ${file}`);
        continue;
      }
      if (statusOnly) { console.log(`  pending  ${file}`); continue; }

      const sql = fs.readFileSync(path.join(__dirname, file), 'utf8');
      await client.query('BEGIN');
      try {
        await client.query(sql);
        await client.query('INSERT INTO schema_migrations (file) VALUES ($1)', [file]);
        await client.query('COMMIT');
        console.log(`  applied  ${file}`);
      } catch (err) {
        await client.query('ROLLBACK');
        throw new Error(`${file} failed, nothing from it was applied: ${err.message}`);
      }
    }
    if (!statusOnly) console.log('Database is up to date.');
  } finally {
    await client.end();
  }
}

main().catch(err => {
  console.error(err.message);
  process.exit(1);
});
