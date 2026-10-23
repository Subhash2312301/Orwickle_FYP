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
  pass: process.env.SMTP_PASS || '',
};
smtp.configured = Boolean(smtp.user && smtp.pass);

if (isProduction && !smtp.configured) {
  throw new Error('SMTP_USER and SMTP_PASS are required in production to send OTP emails.');
}

module.exports = Object.freeze({
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
