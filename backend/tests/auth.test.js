// End-to-end tests for /api/auth against the real database.
// Test accounts use the @test.orwickle.dev domain and are deleted afterwards.
// Run: npm test

process.env.NODE_ENV = 'test';

const { test, after, before } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');

const app = require('../src/app');
const { pool } = require('../src/db/pool');
const { outbox } = require('../src/services/mailer');
const { isCommonPassword } = require('../src/modules/auth/passwordPolicy');
const { DOMAIN, cleanup } = require('./helpers');

const email = `user${Date.now()}${DOMAIN}`;
const PASSWORD = 'Orbit#Lane42';
const NEW_PASSWORD = 'Maple!River77';
const NEWER_PASSWORD = 'Cobalt$Tide19';

const api = request(app);
const registerBody = overrides => ({
  fullName: 'Test Owner', email, password: PASSWORD, role: 'owner', acceptTerms: true, ...overrides,
});
const lastCodeFor = to => {
  const mail = [...outbox].reverse().find(m => m.to === to);
  return mail && mail.text.match(/\b(\d{6})\b/)[1];
};
// lets a test request a new OTP without waiting for the 60-second cooldown
const skipCooldown = () => pool.query(
  `UPDATE auth_tokens SET created_at = created_at - interval '2 minutes'
    WHERE user_id = (SELECT id FROM users WHERE email = $1)`, [email]);
const auditActions = async () => (await pool.query(
  `SELECT action FROM audit_logs WHERE entity_id = (SELECT id FROM users WHERE email = $1)`, [email]))
  .rows.map(r => r.action);

before(cleanup);
after(async () => {
  await cleanup();
  await pool.end();
});

let session;   // { accessToken, refreshToken }

test('common passwords are recognised even when disguised', () => {
  for (const weak of ['Password1!', 'P@ssw0rd1!', 'Pakistan@123', 'Qwerty123!', 'Welcome#2026', 'Abc!1234']) {
    assert.equal(isCommonPassword(weak), true, weak);
  }
  for (const strong of [PASSWORD, NEW_PASSWORD, 'Karachi-Blue-Kite9']) {
    assert.equal(isCommonPassword(strong), false, strong);
  }
});

test('register rejects invalid input with field messages', async () => {
  const res = await api.post('/api/auth/register')
    .send({ fullName: 'A', email: 'not-an-email', password: 'weak', role: 'admin' });
  assert.equal(res.status, 400);
  assert.equal(res.body.error.code, 'VALIDATION_ERROR');
  assert.ok(res.body.error.details.fullName);
  assert.equal(res.body.error.details.email, 'Enter a valid email address');
  assert.equal(res.body.error.details.password, 'Password must be at least 8 characters');
  assert.equal(res.body.error.details.role, 'Choose Project Owner, Investor or Buyer');
  assert.equal(res.body.error.details.acceptTerms, 'You must accept the terms to continue');
});

test('register enforces password complexity', async () => {
  const cases = {
    Orbitlane42: 'Password must contain a special character (e.g. ! @ # $)',
    'Pakistan@123': 'This password is too common. Choose something harder to guess.',
    'Owner#Lane42': 'Password must not contain your name or email',
  };
  for (const [password, message] of Object.entries(cases)) {
    const res = await api.post('/api/auth/register').send(registerBody({ password }));
    assert.equal(res.status, 400, password);
    assert.equal(res.body.error.details.password, message);
  }
});

test('register creates an unverified account and emails an OTP', async () => {
  const res = await api.post('/api/auth/register').send(registerBody({ email: email.toUpperCase() }));
  assert.equal(res.status, 201);
  assert.equal(res.body.email, email);   // stored lower-cased
  assert.match(lastCodeFor(email), /^\d{6}$/);

  const { rows } = await pool.query(
    `SELECT u.role, u.email_verified_at, u.terms_accepted_at, o.user_id AS owner_row
       FROM users u LEFT JOIN owner_profiles o ON o.user_id = u.id WHERE u.email = $1`, [email]);
  assert.equal(rows[0].role, 'owner');
  assert.equal(rows[0].email_verified_at, null);
  assert.ok(rows[0].terms_accepted_at, 'terms acceptance recorded');
  assert.ok(rows[0].owner_row, 'owner profile row created');
});

test('registering the same unverified email again points to verification', async () => {
  const res = await api.post('/api/auth/register').send(registerBody());
  assert.equal(res.status, 409);
  assert.equal(res.body.error.code, 'EMAIL_NOT_VERIFIED');
});

test('login is blocked until the email is verified', async () => {
  const res = await api.post('/api/auth/login').send({ email, password: PASSWORD });
  assert.equal(res.status, 403);
  assert.equal(res.body.error.code, 'EMAIL_NOT_VERIFIED');
});

test('a wrong OTP is rejected and counts an attempt', async () => {
  const wrong = lastCodeFor(email) === '000000' ? '111111' : '000000';
  const res = await api.post('/api/auth/verify-email').send({ email, otp: wrong });
  assert.equal(res.status, 400);
  assert.equal(res.body.error.code, 'INVALID_OTP');
  assert.equal(res.body.error.details.remainingAttempts, 4);
});

test('a new OTP cannot be requested within 60 seconds', async () => {
  const res = await api.post('/api/auth/resend-otp').send({ email, purpose: 'email_verify' });
  assert.equal(res.status, 429);
  assert.equal(res.body.error.code, 'OTP_COOLDOWN');
  assert.ok(res.body.error.details.retryAfterSeconds > 0);
});

test('the correct OTP verifies the email and logs the user in', async () => {
  const res = await api.post('/api/auth/verify-email').send({ email, otp: lastCodeFor(email) });
  assert.equal(res.status, 200);
  assert.ok(res.body.accessToken && res.body.refreshToken);
  assert.equal(res.body.expiresIn, 900);
  assert.equal(res.body.user.emailVerified, true);
  assert.equal(res.body.user.role, 'owner');
  session = res.body;
});

test('a used OTP cannot be used again', async () => {
  const res = await api.post('/api/auth/verify-email').send({ email, otp: lastCodeFor(email) });
  assert.equal(res.status, 409);
  assert.equal(res.body.error.code, 'EMAIL_ALREADY_VERIFIED');
});

test('a verified email cannot be registered again', async () => {
  const res = await api.post('/api/auth/register').send(registerBody({ fullName: 'Someone', role: 'buyer' }));
  assert.equal(res.status, 409);
  assert.equal(res.body.error.code, 'EMAIL_TAKEN');
});

test('/me needs a valid access token', async () => {
  assert.equal((await api.get('/api/auth/me')).status, 401);
  assert.equal((await api.get('/api/auth/me').set('Authorization', 'Bearer nonsense')).status, 401);

  const res = await api.get('/api/auth/me').set('Authorization', `Bearer ${session.accessToken}`);
  assert.equal(res.status, 200);
  assert.equal(res.body.user.email, email);
  assert.equal(res.body.user.fullName, 'Test Owner');
});

test('login rejects a wrong password with a generic message', async () => {
  const wrong = await api.post('/api/auth/login').send({ email, password: 'Wrong1234' });
  const unknown = await api.post('/api/auth/login').send({ email: `nobody${DOMAIN}`, password: 'Wrong1234' });
  assert.equal(wrong.status, 401);
  assert.equal(unknown.status, 401);
  assert.equal(wrong.body.error.message, unknown.body.error.message);
});

test('login with the right password returns a session and resets the failure count', async () => {
  const res = await api.post('/api/auth/login').send({ email, password: PASSWORD });
  assert.equal(res.status, 200);
  session = res.body;
  const { rows } = await pool.query('SELECT failed_login_count FROM users WHERE email = $1', [email]);
  assert.equal(rows[0].failed_login_count, 0);
});

test('refresh rotates the tokens; reusing an old refresh token ends all sessions', async () => {
  const first = await api.post('/api/auth/refresh').send({ refreshToken: session.refreshToken });
  assert.equal(first.status, 200);
  assert.notEqual(first.body.refreshToken, session.refreshToken);

  const reused = await api.post('/api/auth/refresh').send({ refreshToken: session.refreshToken });
  assert.equal(reused.status, 401);
  assert.equal(reused.body.error.code, 'SESSION_EXPIRED');

  // the newest token was revoked too, because the reuse looked like a stolen token
  const newest = await api.post('/api/auth/refresh').send({ refreshToken: first.body.refreshToken });
  assert.equal(newest.status, 401);
});

test('a session unused for more than 15 minutes expires', async () => {
  const login = await api.post('/api/auth/login').send({ email, password: PASSWORD });
  await pool.query(
    `UPDATE auth_tokens SET last_used_at = now() - interval '16 minutes'
      WHERE type = 'refresh' AND used_at IS NULL
        AND user_id = (SELECT id FROM users WHERE email = $1)`, [email]);
  const res = await api.post('/api/auth/refresh').send({ refreshToken: login.body.refreshToken });
  assert.equal(res.status, 401);
  assert.equal(res.body.error.code, 'SESSION_EXPIRED');
});

test('logout ends the session', async () => {
  const login = await api.post('/api/auth/login').send({ email, password: PASSWORD });
  assert.equal((await api.post('/api/auth/logout').send({ refreshToken: login.body.refreshToken })).status, 204);
  const res = await api.post('/api/auth/refresh').send({ refreshToken: login.body.refreshToken });
  assert.equal(res.status, 401);
});

test('change password checks the current password and the new one', async () => {
  const login = (await api.post('/api/auth/login').send({ email, password: PASSWORD })).body;
  const change = body => api.post('/api/auth/change-password')
    .set('Authorization', `Bearer ${login.accessToken}`).send(body);

  const wrongCurrent = await change({ currentPassword: 'Nope#1234x', newPassword: NEW_PASSWORD });
  assert.equal(wrongCurrent.status, 400);
  assert.equal(wrongCurrent.body.error.details.currentPassword, 'Current password is incorrect');

  const same = await change({ currentPassword: PASSWORD, newPassword: PASSWORD });
  assert.equal(same.body.error.details.newPassword, 'New password must be different from your current password');

  const ok = await change({ currentPassword: PASSWORD, newPassword: NEW_PASSWORD });
  assert.equal(ok.status, 200);
  assert.ok(ok.body.refreshToken, 'a fresh session for this device');

  // other sessions ended, new password works
  assert.equal((await api.post('/api/auth/refresh').send({ refreshToken: login.refreshToken })).status, 401);
  assert.equal((await api.post('/api/auth/login').send({ email, password: NEW_PASSWORD })).status, 200);
});

test('forgot password gives the same answer for unknown emails and sends nothing', async () => {
  const before = outbox.length;
  const res = await api.post('/api/auth/forgot-password').send({ email: `ghost${DOMAIN}` });
  assert.equal(res.status, 200);
  assert.match(res.body.message, /If an account exists/);
  assert.equal(outbox.length, before);
});

test('five wrong reset codes lock that code', async () => {
  await api.post('/api/auth/forgot-password').send({ email });
  const code = lastCodeFor(email);
  const wrong = code === '000000' ? '111111' : '000000';
  for (let i = 0; i < 5; i++) {
    await api.post('/api/auth/reset-password').send({ email, otp: wrong, newPassword: NEWER_PASSWORD });
  }
  const res = await api.post('/api/auth/reset-password').send({ email, otp: code, newPassword: NEWER_PASSWORD });
  assert.equal(res.status, 400);
  assert.equal(res.body.error.code, 'OTP_TOO_MANY_ATTEMPTS');
});

test('reset password with a fresh OTP changes the password and ends old sessions', async () => {
  const oldSession = (await api.post('/api/auth/login').send({ email, password: NEW_PASSWORD })).body;

  await skipCooldown();
  await api.post('/api/auth/forgot-password').send({ email });
  const weak = await api.post('/api/auth/reset-password')
    .send({ email, otp: lastCodeFor(email), newPassword: 'nouppercase1' });
  assert.equal(weak.status, 400);
  assert.equal(weak.body.error.details.newPassword, 'Password must contain an uppercase letter');

  const sameAsOld = await api.post('/api/auth/reset-password')
    .send({ email, otp: lastCodeFor(email), newPassword: NEW_PASSWORD });
  assert.equal(sameAsOld.body.error.details.newPassword, 'New password must be different from your current password');

  const res = await api.post('/api/auth/reset-password')
    .send({ email, otp: lastCodeFor(email), newPassword: NEWER_PASSWORD });
  assert.equal(res.status, 200);

  assert.equal((await api.post('/api/auth/login').send({ email, password: NEW_PASSWORD })).status, 401);
  assert.equal((await api.post('/api/auth/login').send({ email, password: NEWER_PASSWORD })).status, 200);
  assert.equal((await api.post('/api/auth/refresh').send({ refreshToken: oldSession.refreshToken })).status, 401);
});

test('five wrong passwords in a row lock the account for 15 minutes', async () => {
  const statuses = [];
  for (let i = 0; i < 5; i++) {
    statuses.push((await api.post('/api/auth/login').send({ email, password: 'Wrong#1234' })).status);
  }
  assert.deepEqual(statuses, [401, 401, 401, 401, 429]);

  const locked = await api.post('/api/auth/login').send({ email, password: NEWER_PASSWORD });
  assert.equal(locked.status, 429, 'even the right password is refused while locked');
  assert.equal(locked.body.error.code, 'ACCOUNT_LOCKED');
  assert.ok(locked.body.error.details.retryAfterSeconds > 800);
});

test('important auth events are written to the audit log', async () => {
  const actions = await auditActions();
  for (const action of ['auth.registered', 'auth.email_verified', 'auth.login', 'auth.login_failed',
    'auth.account_locked', 'auth.logout', 'auth.password_changed', 'auth.password_reset',
    'auth.token_reuse_detected']) {
    assert.ok(actions.includes(action), `missing ${action}`);
  }
});
