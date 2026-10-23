// Business rules for registration, OTP verification, login sessions and password reset.

const bcrypt = require('bcryptjs');
const { pool, withTransaction } = require('../../db/pool');
const authConfig = require('../../config/auth');
const HttpError = require('../../utils/httpError');
const { sendMail } = require('../../services/mailer');
const { otpEmail } = require('../../services/emailTemplates');
const { generateOtp, hashOtp, otpMatches } = require('./otp');
const { signAccessToken, newRefreshToken, hashToken } = require('./tokens');

const ROLE_PROFILE_TABLE = {
  owner: 'owner_profiles',
  investor: 'investor_profiles',
  buyer: 'buyer_profiles',
};

// Compared against when the email does not exist, so a failed login takes the same time either way.
const DUMMY_PASSWORD_HASH = bcrypt.hashSync('timing-equaliser', authConfig.bcryptRounds);

const GENERIC_OTP_SENT = 'If an account exists for this email, a code has been sent.';

// ---------- helpers ----------

async function findUserByEmail(db, email) {
  const { rows } = await db.query(
    `SELECT u.id, u.email, u.role, u.status, u.password_hash, u.email_verified_at, p.full_name
       FROM users u
       JOIN profiles p ON p.user_id = u.id
      WHERE u.email = $1`,
    [email]);
  return rows[0] || null;
}

function publicUser(user) {
  return {
    id: user.id,
    email: user.email,
    role: user.role,
    fullName: user.full_name,
    emailVerified: Boolean(user.email_verified_at),
  };
}

// Creates a new OTP (replacing any unused one) inside the caller's transaction and returns the code.
async function issueOtp(client, user, type) {
  const { rows } = await client.query(
    `SELECT created_at FROM auth_tokens
      WHERE user_id = $1 AND type = $2
      ORDER BY created_at DESC LIMIT 1`,
    [user.id, type]);
  if (rows[0]) {
    const waitMs = authConfig.otpResendCooldownMs - (Date.now() - rows[0].created_at.getTime());
    if (waitMs > 0) {
      throw new HttpError(429, 'OTP_COOLDOWN', 'Please wait before requesting a new code',
        { retryAfterSeconds: Math.ceil(waitMs / 1000) });
    }
  }

  await client.query(
    `UPDATE auth_tokens SET used_at = now()
      WHERE user_id = $1 AND type = $2 AND used_at IS NULL`,
    [user.id, type]);

  const code = generateOtp();
  await client.query(
    `INSERT INTO auth_tokens (user_id, type, token_hash, expires_at)
     VALUES ($1, $2, $3, now() + make_interval(secs => $4))`,
    [user.id, type, hashOtp(user.id, type, code), authConfig.otpTtlMs / 1000]);
  return code;
}

async function sendOtpEmail(user, type, code) {
  const mail = otpEmail({
    type,
    name: user.full_name,
    code,
    validMinutes: authConfig.otpTtlMs / 60000,
  });
  await sendMail({ to: user.email, ...mail });
}

// Checks a submitted OTP. Wrong guesses are counted outside the caller's transaction so a
// failed request still uses up an attempt. On success the OTP is marked used inside `client`.
async function consumeOtp(client, user, type, code) {
  const { rows } = await pool.query(
    `SELECT id, token_hash, attempts, expires_at FROM auth_tokens
      WHERE user_id = $1 AND type = $2 AND used_at IS NULL
      ORDER BY created_at DESC LIMIT 1`,
    [user.id, type]);
  const otp = rows[0];

  if (!otp || otp.expires_at <= new Date()) {
    throw new HttpError(400, 'OTP_EXPIRED', 'This code has expired. Please request a new one.');
  }
  if (otp.attempts >= authConfig.otpMaxAttempts) {
    throw new HttpError(400, 'OTP_TOO_MANY_ATTEMPTS', 'Too many wrong attempts. Please request a new code.');
  }
  if (!otpMatches(otp.token_hash, user.id, type, code)) {
    await pool.query('UPDATE auth_tokens SET attempts = attempts + 1 WHERE id = $1', [otp.id]);
    const remainingAttempts = authConfig.otpMaxAttempts - otp.attempts - 1;
    throw new HttpError(400, 'INVALID_OTP',
      remainingAttempts > 0
        ? `Incorrect code. ${remainingAttempts} attempt${remainingAttempts === 1 ? '' : 's'} left.`
        : 'Incorrect code. Please request a new one.',
      { remainingAttempts });
  }

  const used = await client.query(
    `UPDATE auth_tokens SET used_at = now(), last_used_at = now()
      WHERE id = $1 AND used_at IS NULL AND attempts < $2`,
    [otp.id, authConfig.otpMaxAttempts]);
  if (used.rowCount === 0) {
    throw new HttpError(400, 'OTP_EXPIRED', 'This code has expired. Please request a new one.');
  }
}

async function createSession(client, user, userAgent) {
  const refreshToken = newRefreshToken();
  await client.query(
    `INSERT INTO auth_tokens (user_id, type, token_hash, expires_at, last_used_at, user_agent)
     VALUES ($1, 'refresh', $2, now() + make_interval(secs => $3), now(), $4)`,
    [user.id, hashToken(refreshToken), authConfig.sessionMaxLifetimeMs / 1000, userAgent?.slice(0, 300) || null]);
  return {
    accessToken: signAccessToken(user),
    refreshToken,
    expiresIn: authConfig.accessTokenTtlSeconds,
    user: publicUser(user),
  };
}

async function revokeAllSessions(db, userId) {
  await db.query(
    `UPDATE auth_tokens SET used_at = now()
      WHERE user_id = $1 AND type = 'refresh' AND used_at IS NULL`,
    [userId]);
}

const sessionExpired = () =>
  new HttpError(401, 'SESSION_EXPIRED', 'Your session has expired, please log in again');

// ---------- use cases ----------

async function register({ fullName, email, password, role }) {
  const passwordHash = await bcrypt.hash(password, authConfig.bcryptRounds);

  const { user, code } = await withTransaction(async client => {
    const existing = await findUserByEmail(client, email);
    if (existing) {
      throw existing.email_verified_at
        ? new HttpError(409, 'EMAIL_TAKEN', 'An account with this email already exists')
        : new HttpError(409, 'EMAIL_NOT_VERIFIED', 'This email is registered but not verified yet', { email });
    }

    let created;
    try {
      ({ rows: [created] } = await client.query(
        `INSERT INTO users (email, password_hash, role) VALUES ($1, $2, $3)
         RETURNING id, email, role, status, email_verified_at`,
        [email, passwordHash, role]));
    } catch (err) {
      if (err.code === '23505') throw new HttpError(409, 'EMAIL_TAKEN', 'An account with this email already exists');
      throw err;
    }
    await client.query('INSERT INTO profiles (user_id, full_name) VALUES ($1, $2)', [created.id, fullName]);
    await client.query(`INSERT INTO ${ROLE_PROFILE_TABLE[role]} (user_id) VALUES ($1)`, [created.id]);

    const newUser = { ...created, full_name: fullName };
    return { user: newUser, code: await issueOtp(client, newUser, 'email_verify') };
  });

  await sendOtpEmail(user, 'email_verify', code);
  return { message: 'Account created. Enter the code sent to your email.', email: user.email };
}

async function verifyEmail({ email, otp }, { userAgent }) {
  const user = await findUserByEmail(pool, email);
  if (!user) throw new HttpError(400, 'OTP_EXPIRED', 'This code has expired. Please request a new one.');
  if (user.email_verified_at) {
    throw new HttpError(409, 'EMAIL_ALREADY_VERIFIED', 'This email is already verified. Please log in.');
  }

  return withTransaction(async client => {
    await consumeOtp(client, user, 'email_verify', otp);
    const { rows: [verified] } = await client.query(
      'UPDATE users SET email_verified_at = now(), last_login_at = now() WHERE id = $1 RETURNING email_verified_at',
      [user.id]);
    return createSession(client, { ...user, ...verified }, userAgent);
  });
}

// purpose 'password_reset' never reveals whether the email exists.
async function sendOtpAgain({ email, purpose }) {
  const user = await findUserByEmail(pool, email);
  const eligible = user && user.status === 'active' &&
    (purpose === 'email_verify' ? !user.email_verified_at : Boolean(user.email_verified_at));
  if (!eligible) return { message: GENERIC_OTP_SENT };

  let code;
  try {
    code = await withTransaction(client => issueOtp(client, user, purpose));
  } catch (err) {
    if (purpose === 'password_reset' && err.code === 'OTP_COOLDOWN') return { message: GENERIC_OTP_SENT };
    throw err;
  }
  await sendOtpEmail(user, purpose, code);
  return { message: GENERIC_OTP_SENT };
}

async function login({ email, password }, { userAgent }) {
  const user = await findUserByEmail(pool, email);
  const passwordOk = await bcrypt.compare(password, user?.password_hash ?? DUMMY_PASSWORD_HASH);
  if (!user || !passwordOk) {
    throw new HttpError(401, 'INVALID_CREDENTIALS', 'Incorrect email or password');
  }
  if (user.status !== 'active') {
    throw new HttpError(403, 'ACCOUNT_SUSPENDED', 'This account has been suspended. Contact support.');
  }
  if (!user.email_verified_at) {
    throw new HttpError(403, 'EMAIL_NOT_VERIFIED', 'Please verify your email before logging in', { email });
  }

  return withTransaction(async client => {
    await client.query('UPDATE users SET last_login_at = now() WHERE id = $1', [user.id]);
    return createSession(client, user, userAgent);
  });
}

// Swaps a refresh token for a new pair. Each refresh token works once; presenting a used
// one again means it was copied, so every session of that user is ended.
async function refresh({ refreshToken }, { userAgent }) {
  const { rows } = await pool.query(
    `SELECT t.id, t.used_at, t.expires_at, t.last_used_at,
            u.id AS user_id, u.email, u.role, u.status, u.email_verified_at, p.full_name
       FROM auth_tokens t
       JOIN users u ON u.id = t.user_id
       JOIN profiles p ON p.user_id = u.id
      WHERE t.token_hash = $1 AND t.type = 'refresh'`,
    [hashToken(refreshToken)]);
  const session = rows[0];
  if (!session) throw sessionExpired();

  if (session.used_at) {
    await revokeAllSessions(pool, session.user_id);
    throw sessionExpired();
  }
  const idleMs = Date.now() - session.last_used_at.getTime();
  if (session.expires_at <= new Date() || idleMs > authConfig.sessionIdleTimeoutMs) {
    await pool.query('UPDATE auth_tokens SET used_at = now() WHERE id = $1', [session.id]);
    throw sessionExpired();
  }
  if (session.status !== 'active') {
    await revokeAllSessions(pool, session.user_id);
    throw new HttpError(403, 'ACCOUNT_SUSPENDED', 'This account has been suspended. Contact support.');
  }

  const user = { ...session, id: session.user_id };
  return withTransaction(async client => {
    const rotated = await client.query(
      'UPDATE auth_tokens SET used_at = now() WHERE id = $1 AND used_at IS NULL', [session.id]);
    if (rotated.rowCount === 0) throw sessionExpired();
    return createSession(client, user, userAgent);
  });
}

async function logout({ refreshToken }) {
  await pool.query(
    `UPDATE auth_tokens SET used_at = now()
      WHERE token_hash = $1 AND type = 'refresh' AND used_at IS NULL`,
    [hashToken(refreshToken)]);
}

async function forgotPassword({ email }) {
  return sendOtpAgain({ email, purpose: 'password_reset' });
}

async function resetPassword({ email, otp, newPassword }) {
  const user = await findUserByEmail(pool, email);
  if (!user || !user.email_verified_at || user.status !== 'active') {
    throw new HttpError(400, 'OTP_EXPIRED', 'This code has expired. Please request a new one.');
  }
  const passwordHash = await bcrypt.hash(newPassword, authConfig.bcryptRounds);

  await withTransaction(async client => {
    await consumeOtp(client, user, 'password_reset', otp);
    await client.query('UPDATE users SET password_hash = $2 WHERE id = $1', [user.id, passwordHash]);
    await revokeAllSessions(client, user.id);
  });
  return { message: 'Password changed. Please log in with your new password.' };
}

async function getMe(userId) {
  const { rows } = await pool.query(
    `SELECT u.id, u.email, u.role, u.status, u.email_verified_at, p.full_name
       FROM users u JOIN profiles p ON p.user_id = u.id
      WHERE u.id = $1`,
    [userId]);
  if (!rows[0] || rows[0].status !== 'active') throw sessionExpired();
  return { user: publicUser(rows[0]) };
}

module.exports = {
  register,
  verifyEmail,
  sendOtpAgain,
  login,
  refresh,
  logout,
  forgotPassword,
  resetPassword,
  getMe,
};
