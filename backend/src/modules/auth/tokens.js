// Access tokens (short-lived JWT) and refresh tokens (random strings stored only as a hash).

const crypto = require('node:crypto');
const jwt = require('jsonwebtoken');
const env = require('../../config/env');
const authConfig = require('../../config/auth');

function signAccessToken(user) {
  return jwt.sign({ role: user.role }, env.jwtSecret, {
    subject: user.id,
    expiresIn: authConfig.accessTokenTtlSeconds,
    algorithm: 'HS256',
  });
}

// Throws if the token is invalid or expired.
function verifyAccessToken(token) {
  const payload = jwt.verify(token, env.jwtSecret, { algorithms: ['HS256'] });
  return { id: payload.sub, role: payload.role };
}

function newRefreshToken() {
  return crypto.randomBytes(32).toString('base64url');
}

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

module.exports = { signAccessToken, verifyAccessToken, newRefreshToken, hashToken };
