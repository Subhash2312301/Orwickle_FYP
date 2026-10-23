// Limits repeated requests from one IP address to slow down password guessing and email spam.
// Switched off in automated tests.

const { rateLimit } = require('express-rate-limit');
const env = require('../config/env');

function limiter(limit, windowMinutes) {
  return rateLimit({
    windowMs: windowMinutes * 60 * 1000,
    limit,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    skip: () => env.isTest,
    handler: (req, res) => res.status(429).json({
      error: { code: 'TOO_MANY_REQUESTS', message: 'Too many attempts. Please wait a few minutes and try again.' },
    }),
  });
}

module.exports = {
  loginLimiter: limiter(10, 15),   // 10 login attempts per 15 minutes
  otpLimiter: limiter(15, 15),     // register / verify / resend / forgot / reset
};
