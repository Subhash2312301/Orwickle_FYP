// Shared PostgreSQL connection pool (Supabase session pooler).

const { Pool } = require('pg');
const env = require('../config/env');

const pool = new Pool({
  connectionString: env.databaseUrl,
  ssl: { rejectUnauthorized: false },   // Supabase uses its own CA
  max: 5,                               // free-tier pooler allows few connections
  idleTimeoutMillis: 30_000,
});

pool.on('error', err => {
  console.error('Unexpected database error:', err.message);
});

// Runs fn(client) inside BEGIN/COMMIT; rolls back if fn throws.
// Used wherever several writes must succeed or fail together (offers, agreements, deals).
async function withTransaction(fn) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

module.exports = { pool, withTransaction };
