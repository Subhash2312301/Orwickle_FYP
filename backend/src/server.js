// Entry point: starts the HTTP server and shuts down cleanly on Ctrl+C or when the host stops it.

const env = require('./config/env');
const app = require('./app');
const { pool } = require('./db/pool');

const server = app.listen(env.port, () => {
  console.log(`Orwickle API listening on http://localhost:${env.port} (${env.nodeEnv})`);
});

function shutdown(signal) {
  console.log(`${signal} received, shutting down...`);
  server.close(async () => {
    await pool.end();
    process.exit(0);
  });
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
