// Tests for /api/admin review of accounts and listings.

process.env.NODE_ENV = 'test';

const { test, after, before } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');

const app = require('../src/app');
const { pool } = require('../src/db/pool');
const { outbox } = require('../src/services/mailer');
const { expireOverdue } = require('../src/services/verification');
const { createVerifiedUser, cleanup } = require('./helpers');

const api = request(app);
let admin, owner, ownerEmail, ownerId, investor, investorId, investorToken, categoryId;

const as = token => ({
  get: url => api.get(url).set('Authorization', `Bearer ${token}`),
  post: (url, body) => api.post(url).set('Authorization', `Bearer ${token}`).send(body),
  put: (url, body) => api.put(url).set('Authorization', `Bearer ${token}`).send(body),
  del: url => api.delete(url).set('Authorization', `Bearer ${token}`),
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
  bio: 'I build apps for schools in Karachi.',
  linkedinUrl: 'https://www.linkedin.com/in/sara',
  details: {
    isStudent: true,
    university: 'SZABIST',
    degreeProgram: 'BS CS',
    skills: ['Flutter'],
    githubUrl: 'https://github.com/sara-ahmed',
    portfolioUrl: 'https://sara.dev',
  },
};
const listing = () => ({
  listingType: 'sale',
  categoryId,
  title: 'School fee tracker',
  shortDescription: 'Track school fees and send reminders to parents automatically.',
  projectStage: 'launched',
  askingAmount: 250000,
  confidential: {
    fullDescription: 'Complete app with admin panel and SMS reminders.',
    problemStatement: 'Schools track fees on paper.',
    businessModel: 'One-time sale of the source code.',
    financialSummary: 'Hosting costs 3,000 PKR a month.',
    ipOwnershipNotes: 'Written entirely by the owner.',
    transferDetails: 'Source code and setup help.',
  },
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
  const i = await loginAs('investor', 'Farhan Malik');
  investor = i.client;
  investorId = i.id;
  investorToken = i.session.accessToken;
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

  // starting the review marks the account as under review by this admin
  const started = await admin.post(`/api/admin/users/${ownerId}/review/start`);
  assert.equal(started.body.started, true);
  const underReview = await admin.get('/api/admin/reviews/users?status=under_review');
  const entry = underReview.body.users.find(u => u.id === ownerId);
  assert.equal(entry.reviewStatus, 'under_review');
  assert.equal(entry.reviewStartedBy, 'Test Admin');
  assert.equal(entry.decisions.length, 1, 'the earlier request for more information is shown');

  const res = await admin.post(`/api/admin/users/${ownerId}/review`,
    { decision: 'approve', checklist: { 'University ID matches name': true, 'GitHub profile opens': true } });
  assert.equal(res.body.reviewStatus, 'approved');
  assert.match(lastMailTo(ownerEmail).subject, /verified/);

  const noEvidence = await owner.post(`/api/listings/${draft}/publish`);
  assert.equal(noEvidence.body.error.code, 'EVIDENCE_REQUIRED');
  await owner.post(`/api/listings/${draft}/evidence/ownership_proof/link`, { url: 'https://github.com/sara/fees' });
  const published = await owner.post(`/api/listings/${draft}/publish`);
  assert.equal(published.status, 200);
  assert.equal(published.body.listing.reviewStatus, 'pending');
});

test('admins verify projects: owner, evidence and claims; changes or rejection send it back to draft', async () => {
  const queue = await admin.get('/api/admin/reviews/listings');
  const pending = queue.body.listings.find(l => l.listing.title === 'School fee tracker');
  assert.ok(pending.confidential.fullDescription, 'admins see the confidential details to review them');
  assert.equal(pending.owner.email, ownerEmail, 'admins see who owns the project');
  assert.equal(pending.owner.reviewStatus, 'approved');
  assert.equal(pending.owner.details.githubUrl, 'https://github.com/sara');
  assert.deepEqual(pending.evidence.map(e => e.kind), ['ownership_proof']);
  const id = pending.listing.id;

  assert.equal((await admin.post(`/api/admin/listings/${id}/review/start`)).body.started, true);
  assert.equal((await owner.get(`/api/listings/${id}`)).body.listing.reviewStatus, 'under_review');

  const changes = await admin.post(`/api/admin/listings/${id}/review`,
    { decision: 'request_more', reason: 'Add a demo video as project evidence.' });
  assert.equal(changes.status, 200);
  assert.equal(changes.body.listing.status, 'draft');
  assert.equal(changes.body.listing.reviewStatus, 'needs_evidence');
  assert.equal(lastMailTo(ownerEmail).subject, 'Your listing needs changes');

  await owner.post(`/api/listings/${id}/evidence/project_evidence/link`, { url: 'https://youtu.be/demo' });
  await owner.post(`/api/listings/${id}/publish`);
  const rejected = await admin.post(`/api/admin/listings/${id}/review`,
    { decision: 'reject', reason: 'Add a screenshot of the admin panel as the cover.' });
  assert.equal(rejected.body.listing.status, 'draft');
  assert.equal(rejected.body.listing.reviewStatus, 'rejected');
  assert.match(lastMailTo(ownerEmail).text, /Add a screenshot/);
  const kept = await owner.del(`/api/listings/${id}`);
  assert.equal(kept.status, 409, 'a reviewed listing cannot be deleted: its review history is kept');
  assert.equal(kept.body.error.code, 'LISTING_HAS_HISTORY');
  assert.equal((await owner.get(`/api/listings/${id}`)).body.listing.reviewNote,
    'Add a screenshot of the admin panel as the cover.');

  await owner.post(`/api/listings/${id}/publish`);
  assert.equal((await investor.get(`/api/listings/${id}`)).status, 404, 'hidden while pending');

  const approved = await admin.post(`/api/admin/listings/${id}/review`, { decision: 'approve' });
  assert.equal(approved.body.listing.reviewStatus, 'approved');
  assert.equal((await investor.get(`/api/listings/${id}`)).status, 200, 'visible once approved');

  const { rows } = await pool.query(
    `SELECT decision, evidence_reviewed FROM review_decisions WHERE subject_listing_id = $1 ORDER BY created_at`, [id]);
  assert.deepEqual(rows.map(r => r.decision), ['request_more', 'reject', 'approve']);
  assert.deepEqual(rows[0].evidence_reviewed.map(e => e.kind), ['ownership_proof']);
  assert.deepEqual(rows[2].evidence_reviewed.map(e => e.kind), ['ownership_proof', 'project_evidence']);
});

test('every decision is recorded with the reviewer, reason and the evidence reviewed', async () => {
  const { rows } = await pool.query(
    `SELECT decision, reason, evidence_reviewed FROM review_decisions WHERE subject_user_id = $1 ORDER BY created_at`,
    [ownerId]);
  assert.deepEqual(rows.map(r => r.decision), ['request_more', 'approve']);
  assert.deepEqual(rows[1].evidence_reviewed.map(e => e.kind).sort(), ['university_id_back', 'university_id_front']);
  const checklist = await pool.query(
    `SELECT checklist FROM review_decisions WHERE subject_user_id = $1 AND decision = 'approve'`, [ownerId]);
  assert.equal(checklist.rows[0].checklist['University ID matches name'], true);
  const audit = await pool.query(`SELECT action FROM audit_logs WHERE action LIKE 'admin.%' AND entity_id = $1`, [ownerId]);
  assert.deepEqual(audit.rows.map(r => r.action).sort(),
    ['admin.user_approved', 'admin.user_needs_evidence', 'admin.user_review_started']);

  const trail = await admin.get('/api/admin/reviews/decisions?subject=users');
  const mine = trail.body.decisions.filter(d => d.subject.id === ownerId);
  assert.deepEqual(mine.map(d => d.decision), ['approve', 'request_more']);
  assert.equal(mine[0].reviewer, 'Test Admin');
  assert.equal(mine[0].subject.name, 'Sara Ahmed');
  assert.equal(mine[0].evidenceReviewed.length, 2);
  const projects = await admin.get('/api/admin/reviews/decisions?subject=listings');
  assert.ok(projects.body.decisions.every(d => d.subject.type === 'listing'));
});

test('investors are verified in their own queue from their professional details and evidence', async () => {
  for (const [kind, url] of [['network_affiliation', 'https://angels.pk/farhan'], ['investment_portfolio', 'https://angel.co/farhan']]) {
    await api.put(`/api/profile/me/documents/${kind}/link`).set('Authorization', `Bearer ${investorToken}`).send({ url });
  }
  const saved = await investor.put('/api/profile/me', {
    fullName: 'Farhan Malik',
    linkedinUrl: 'https://www.linkedin.com/in/farhan',
    details: {
      organization: 'Karachi Angel Network', designation: 'Angel Investor',
      investmentInterests: 'EdTech apps built by students.', investmentStages: ['prototype'],
      minTicket: 500000, maxTicket: 2000000, interests: [categoryId],
    },
  });
  assert.equal(saved.body.profile.reviewStatus, 'pending');

  const investors = await admin.get('/api/admin/reviews/users?role=investor');
  assert.ok(investors.body.users.every(u => u.role === 'investor'));
  const entry = investors.body.users.find(u => u.id === investorId);
  assert.equal(entry.details.organization, 'Karachi Angel Network');
  assert.equal(entry.documents.length, 2);
  assert.equal(entry.emailVerified, true);
  const others = await admin.get('/api/admin/reviews/users?role=others');
  assert.ok(!others.body.users.some(u => u.role === 'investor'));

  const stats = await admin.get('/api/admin/stats');
  assert.ok(stats.body.users.investorsPending >= 1);

  const asked = await admin.post(`/api/admin/users/${investorId}/review`,
    { decision: 'request_more', reason: 'Add your company registration.' });
  assert.equal(asked.body.reviewStatus, 'needs_evidence');
  assert.equal(lastMailTo(entry.email).subject, 'More evidence needed for your Orwickle profile');
});

test('a request for more evidence expires after 30 days without an answer; resubmitting starts again', async () => {
  await pool.query(`UPDATE profiles SET reviewed_at = now() - interval '31 days' WHERE user_id = $1`, [investorId]);
  const expired = await expireOverdue();
  assert.ok(expired.users >= 1);
  assert.equal((await investor.get('/api/profile/me')).body.profile.reviewStatus, 'expired');
  const { rows } = await pool.query(`SELECT action, actor_id FROM audit_logs WHERE entity_id = $1 AND action = 'verification.expired'`,
    [investorId]);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].actor_id, null, 'expired by the system');

  const filtered = await admin.get('/api/admin/users?review=expired');
  assert.ok(filtered.body.users.some(u => u.id === investorId));

  const me = (await investor.get('/api/profile/me')).body.profile;
  const resubmitted = await investor.put('/api/profile/me', {
    fullName: me.fullName, linkedinUrl: me.linkedinUrl,
    details: { ...me.details, interests: me.details.interests.map(c => c.id) },
  });
  assert.equal(resubmitted.status, 200);
  assert.equal(resubmitted.body.profile.reviewStatus, 'pending');
});

test('the overview counts users and listings', async () => {
  const res = await admin.get('/api/admin/stats');
  assert.equal(res.status, 200);
  assert.ok(res.body.users.owners >= 1);
  assert.ok(res.body.users.investors >= 1);
  assert.equal(typeof res.body.users.newToday, 'number');
  assert.equal(typeof res.body.listings.live, 'number');
  assert.equal((await owner.get('/api/admin/stats')).status, 403);
});

test('admins search users and open one with documents, listings and past decisions', async () => {
  const found = await admin.get(`/api/admin/users?search=${encodeURIComponent(ownerEmail)}`);
  assert.equal(found.status, 200);
  assert.deepEqual(found.body.users.map(u => u.email), [ownerEmail]);
  assert.equal(found.body.users[0].reviewStatus, 'approved');

  const owners = await admin.get('/api/admin/users?role=owner');
  assert.ok(owners.body.users.every(u => u.role === 'owner'));
  assert.ok(!owners.body.users.some(u => u.role === 'admin'), 'admins are never listed');

  const detail = await admin.get(`/api/admin/users/${ownerId}`);
  assert.equal(detail.body.user.email, ownerEmail);
  assert.equal(detail.body.profile.documents.length, 2);
  assert.ok(detail.body.listings.length >= 1);
  assert.deepEqual(detail.body.decisions.map(d => d.decision), ['approve', 'request_more']);
  assert.equal(detail.body.decisions[0].evidenceReviewed.length, 2);
});

test('suspending needs a reason, logs the user out and blocks login until reinstated', async () => {
  const creds = await createVerifiedUser('buyer', 'Bad Actor');
  const login = (await api.post('/api/auth/login').send(creds)).body;

  const noReason = await admin.post(`/api/admin/users/${login.user.id}/suspend`, {});
  assert.equal(noReason.status, 400);
  assert.equal(noReason.body.error.details.reason, 'Give a reason');

  const suspended = await admin.post(`/api/admin/users/${login.user.id}/suspend`, { reason: 'Fake company details' });
  assert.equal(suspended.body.status, 'suspended');
  assert.equal(lastMailTo(creds.email).subject, 'Your Orwickle account has been suspended');
  assert.equal((await api.post('/api/auth/refresh').send({ refreshToken: login.refreshToken })).status, 401,
    'existing sessions end');
  const blocked = await api.post('/api/auth/login').send(creds);
  assert.equal(blocked.body.error.code, 'ACCOUNT_SUSPENDED');
  assert.equal((await admin.post(`/api/admin/users/${login.user.id}/suspend`, { reason: 'again' })).status, 409);

  await admin.post(`/api/admin/users/${login.user.id}/reinstate`, { reason: 'Documents checked again' });
  assert.equal((await api.post('/api/auth/login').send(creds)).status, 200);
});

test('the audit log lists admin actions with the actor', async () => {
  const res = await admin.get('/api/admin/audit?action=admin.user_&limit=20');
  assert.equal(res.status, 200);
  const actions = res.body.entries.map(e => e.action);
  assert.ok(actions.includes('admin.user_suspended'));
  assert.ok(actions.includes('admin.user_reinstated'));
  assert.equal(res.body.entries[0].actor.role, 'admin');
});
