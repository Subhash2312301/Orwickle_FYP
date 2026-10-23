// 6-digit one-time codes for email verification and password reset.
// Only an HMAC of (user, purpose, code) is stored, so a database leak does not reveal codes.

const crypto = require('node:crypto');
const env = require('../../config/env');
const authConfig = require('../../config/auth');

function generateOtp() {
  return String(crypto.randomInt(0, 10 ** authConfig.otpLength)).padStart(authConfig.otpLength, '0');
}

function hashOtp(userId, type, code) {
  return crypto.createHmac('sha256', env.jwtSecret).update(`${userId}:${type}:${code}`).digest('hex');
}

function otpMatches(storedHash, userId, type, code) {
  const expected = Buffer.from(storedHash, 'hex');
  const actual = Buffer.from(hashOtp(userId, type, code), 'hex');
  return expected.length === actual.length && crypto.timingSafeEqual(expected, actual);
}

module.exports = { generateOtp, hashOtp, otpMatches };
