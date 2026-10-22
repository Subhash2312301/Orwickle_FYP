// Reads and validates environment variables once, at startup.
// A missing value stops the server immediately instead of failing later on a request.

const REQUIRED = ['DATABASE_URL'];

const missing = REQUIRED.filter(name => !process.env[name]);
if (missing.length > 0) {
  throw new Error(`Missing environment variables: ${missing.join(', ')}. Copy .env.example to .env and fill them in.`);
}

const nodeEnv = process.env.NODE_ENV || 'development';

module.exports = Object.freeze({
  nodeEnv,
  isProduction: nodeEnv === 'production',
  port: Number(process.env.PORT) || 4000,
  databaseUrl: process.env.DATABASE_URL,
  corsOrigin: process.env.CORS_ORIGIN || '*',
});
