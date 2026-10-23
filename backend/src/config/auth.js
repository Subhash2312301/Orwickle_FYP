// Security settings for login sessions and OTPs, kept in one place for the report and viva.

module.exports = Object.freeze({
  accessTokenTtlSeconds: 15 * 60,           // JWT sent with every request
  sessionIdleTimeoutMs: 15 * 60 * 1000,      // session dies after 15 minutes without use
  sessionMaxLifetimeMs: 7 * 24 * 60 * 60 * 1000, // even an active session ends after 7 days

  otpLength: 6,
  otpTtlMs: 10 * 60 * 1000,                 // OTP valid for 10 minutes
  otpMaxAttempts: 5,                         // then a new OTP must be requested
  otpResendCooldownMs: 60 * 1000,            // one new OTP per minute

  bcryptRounds: 12,
});
