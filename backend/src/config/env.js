// Reads and validates environment variables once, at startup.
// A missing value stops the server immediately instead of failing later on a request.

const REQUIRED = ['DATABASE_URL', 'JWT_SECRET'];

const missing = REQUIRED.filter(name => !process.env[name]);
if (missing.length > 0) {
  throw new Error(`Missing environment variables: ${missing.join(', ')}. Copy .env.example to .env and fill them in.`);
}
if (process.env.JWT_SECRET.length < 32) {
  throw new Error('JWT_SECRET must be at least 32 characters long.');
}

const nodeEnv = process.env.NODE_ENV || 'development';
const isProduction = nodeEnv === 'production';

const smtp = {
  host: process.env.SMTP_HOST || 'smtp.gmail.com',
  port: Number(process.env.SMTP_PORT) || 465,
  user: process.env.SMTP_USER || '',
  pass: (process.env.SMTP_PASS || '').replace(/\s/g, ''),   // Google shows app passwords as "abcd efgh ..."
};
smtp.configured = Boolean(smtp.user && smtp.pass);

if (isProduction && !smtp.configured) {
  throw new Error('SMTP_USER and SMTP_PASS are required in production to send OTP emails.');
}

// Supabase Storage when both values are set, otherwise files are kept in backend/uploads (development only)
const storage = Object.freeze({
  supabaseUrl: (process.env.SUPABASE_URL || '').replace(/\/$/, ''),
  serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY || '',
  bucket: process.env.STORAGE_BUCKET || 'private-files',
  get useSupabase() { return Boolean(this.supabaseUrl && this.serviceRoleKey); },
});

if (isProduction && !storage.useSupabase) {
  throw new Error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required in production for file storage.');
}

module.exports = Object.freeze({
  storage,
  nodeEnv,
  isProduction,
  isTest: nodeEnv === 'test',
  port: Number(process.env.PORT) || 4000,
  databaseUrl: process.env.DATABASE_URL,
  corsOrigin: process.env.CORS_ORIGIN || '*',
  jwtSecret: process.env.JWT_SECRET,
  smtp: Object.freeze(smtp),
  mailFrom: process.env.MAIL_FROM || (smtp.user ? `Orwickle <${smtp.user}>` : 'Orwickle <no-reply@orwickle.local>'),
});
