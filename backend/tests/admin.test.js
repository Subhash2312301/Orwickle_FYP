// Tests for /api/admin review of accounts and listings.

process.env.NODE_ENV = 'test';

const { test, after, before } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');

const app = require('../src/app');
const { pool } = require('../src/db/pool');
const { outbox } = require('../src/services/mailer');
const { createVerifiedUser, cleanup } = require('./helpers');

const api = request(app);
let admin, owner, ownerEmail, ownerId, investor, categoryId;

const as = token => ({
  get: url => api.get(url).set('Authorization', `Bearer ${token}`),
  post: (url, body) => api.post(url).set('Authorization', `Bearer ${token}`).send(body),
  put: (url, body) => api.put(url).set('Authorization', `Bearer ${token}`).send(body),
});
const loginAs = async (role, name) => {
  const creds = await createVerifiedUser(role, name);
  const res = await api.post('/api/auth/login').send(creds);
  return { client: as(res.body.accessToken), email: creds.email, id: res.body.user.id, session: res.body };
};
const lastMailTo = to => [...outbox].reverse().find(m => m.to === to);
const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', 'base64');

const ownerProfile = {
  fullName: 'Sara Ahmed',
  headline: 'Student building a school app',
  city: 'Karachi',
  details: { university: 'SZABIST', degreeProgram: 'BS CS', skills: ['Flutter'] },
};
const listing = () => ({
  listingType: 'sale',
  categoryId,
  title: 'School fee tracker',
  shortDescription: 'Track school fees and send reminders to parents automatically.',
  projectStage: 'launched',
  askingAmount: 250000,
  confidential: { fullDescription: 'Complete app with admin panel and SMS reminders.', transferDetails: 'Source code and setup help.' },
});

before(async () => {
  await cleanup();
  categoryId = (await api.get('/api/categories')).body.categories[0].id;
  admin = (await loginAs('admin', 'Test Admin')).client;
  const o = await loginAs('owner', 'Sara Ahmed');
  owner = o.client;
  for (const kind of ['university_id_front', 'university_id_back']) {
    await api.put(`/api/profile/me/documents/${kind}`).set('Authorization', `Bearer ${o.session.accessToken}`).attach('file', PNG, 'id.png');
  }
  ownerEmail = o.email;
  ownerId = o.id;
  investor = (await loginAs('investor')).client;
});
after(async () => {
  await cleanup();
  await pool.end();
});

test('admin endpoints are for admins only', async () => {
  assert.equal((await owner.get('/api/admin/reviews/users')).status, 403);
  assert.equal((await api.get('/api/admin/reviews/users')).status, 401);
});

test('a new account is unreviewed until the profile is saved, then waits for review', async () => {
  const me = await owner.get('/api/profile/me');
  assert.equal(me.body.profile.reviewStatus, 'unreviewed');

  assert.equal((await owner.put('/api/profile/me', ownerProfile)).body.profile.reviewStatus, 'pending');

  const queue = await admin.get('/api/admin/reviews/users');
  const entry = queue.body.users.find(u => u.id === ownerId);
  assert.ok(entry, 'owner is in the pending queue');
  assert.equal(entry.details.university, 'SZABIST');
  assert.equal(entry.documents.length, 2, 'admins see the uploaded ID card');
});

test('rejecting needs a reason; the user is told why and can resubmit', async () => {
  const noReason = await admin.post(`/api/admin/users/${ownerId}/review`, { decision: 'reject' });
  assert.equal(noReason.status, 400);
  assert.equal(noReason.body.error.details.reason, 'Give a reason so the user knows what to change');

  const res = await admin.post(`/api/admin/users/${ownerId}/review`,
    { decision: 'request_more', reason: 'Please add your GitHub profile.' });
  assert.equal(res.status, 200);
  assert.equal(res.body.reviewStatus, 'needs_evidence');
  assert.match(lastMailTo(ownerEmail).text, /Please add your GitHub profile/);

  const me = await owner.get('/api/profile/me');
  assert.equal(me.body.profile.reviewNote, 'Please add your GitHub profile.');

  // saving the profile again sends it back to the queue
  const resubmitted = await owner.put('/api/profile/me',
    { ...ownerProfile, details: { ...ownerProfile.details, githubUrl: 'https://github.com/sara' } });
  assert.equal(resubmitted.body.profile.reviewStatus, 'pending');
});

test('approval unlocks publishing and is emailed', async () => {
  const draft = (await owner.post('/api/listings', listing())).body.listing.id;
  assert.equal((await owner.post(`/api/listings/${draft}/publish`)).status, 403);

  const res = await admin.post(`/api/admin/users/${ownerId}/review`,
    { decision: 'approve', checklist: { 'University ID matches name': true, 'GitHub profile opens': true } });
  assert.equal(res.body.reviewStatus, 'approved');
  assert.match(lastMailTo(ownerEmail).subject, /approved/);

  const published = await owner.post(`/api/listings/${draft}/publish`);
  assert.equal(published.status, 200);
  assert.equal(published.body.listing.reviewStatus, 'pending');
});

test('admins review published listings; rejection sends the listing back to draft', async () => {
  const queue = await admin.get('/api/admin/reviews/listings');
  const pending = queue.body.listings.find(l => l.listing.title === 'School fee tracker');
  assert.ok(pending.confidential.fullDescription, 'admins see the confidential details to review them');
  const id = pending.listing.id;

  const rejected = await admin.post(`/api/admin/listings/${id}/review`,
    { decision: 'reject', reason: 'Add a screenshot of the admin panel as the cover.' });
  assert.equal(rejected.body.listing.status, 'draft');
  assert.equal(rejected.body.listing.reviewStatus, 'rejected');
  assert.match(lastMailTo(ownerEmail).text, /Add a screenshot/);
  assert.equal((await owner.get(`/api/listings/${id}`)).body.listing.reviewNote,
    'Add a screenshot of the admin panel as the cover.');

  await owner.post(`/api/listings/${id}/publish`);
  assert.equal((await investor.get(`/api/listings/${id}`)).status, 404, 'hidden while pending');

  const approved = await admin.post(`/api/admin/listings/${id}/review`, { decision: 'approve' });
  assert.equal(approved.body.listing.reviewStatus, 'approved');
  assert.equal((await investor.get(`/api/listings/${id}`)).status, 200, 'visible once approved');
});

test('every decision is recorded with the reviewer and reason', async () => {
  const { rows } = await pool.query(
    `SELECT decision, reason FROM review_decisions WHERE subject_user_id = $1 ORDER BY created_at`, [ownerId]);
  assert.deepEqual(rows.map(r => r.decision), ['request_more', 'approve']);
  const checklist = await pool.query(
    `SELECT checklist FROM review_decisions WHERE subject_user_id = $1 AND decision = 'approve'`, [ownerId]);
  assert.equal(checklist.rows[0].checklist['University ID matches name'], true);
  const audit = await pool.query(`SELECT action FROM audit_logs WHERE action LIKE 'admin.%' AND entity_id = $1`, [ownerId]);
  assert.deepEqual(audit.rows.map(r => r.action).sort(), ['admin.user_approved', 'admin.user_needs_evidence']);
});
