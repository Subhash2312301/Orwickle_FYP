// Tests for /api/profile/me and /api/categories against the real database.

process.env.NODE_ENV = 'test';

const { test, after, before } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');

const app = require('../src/app');
const { pool } = require('../src/db/pool');
const { createVerifiedUser, cleanup } = require('./helpers');

const api = request(app);
let categories;

async function loginAs(role, name) {
  const creds = await createVerifiedUser(role, name);
  const res = await api.post('/api/auth/login').send(creds);
  assert.equal(res.status, 200);
  return res.body;
}
const getProfile = token => api.get('/api/profile/me').set('Authorization', `Bearer ${token}`);
const putProfile = (token, body) => api.put('/api/profile/me').set('Authorization', `Bearer ${token}`).send(body);

const common = {
  fullName: 'Ayesha Khan',
  headline: 'Final-year CS student building EdTech apps',
  city: 'Karachi',
  bio: 'I build mobile apps.',
  linkedinUrl: 'https://www.linkedin.com/in/ayesha',
};

before(async () => {
  await cleanup();
  categories = (await api.get('/api/categories')).body.categories;
});
after(async () => {
  await cleanup();
  await pool.end();
});

test('categories are listed for everyone', () => {
  assert.ok(categories.length >= 10);
  assert.ok(categories.every(c => c.id && c.name && c.slug));
});

test('profile endpoints need a login', async () => {
  assert.equal((await api.get('/api/profile/me')).status, 401);
  assert.equal((await api.put('/api/profile/me').send(common)).status, 401);
});

test('a new owner starts with an incomplete profile', async () => {
  const session = await loginAs('owner', 'Ayesha Khan');
  assert.equal(session.user.profileCompleted, false);

  const res = await getProfile(session.accessToken);
  assert.equal(res.status, 200);
  assert.equal(res.body.profile.completed, false);
  assert.equal(res.body.profile.fullName, 'Ayesha Khan');
  assert.deepEqual(res.body.profile.details.skills, []);
});

test('owner profile is validated field by field', async () => {
  const session = await loginAs('owner');
  const res = await putProfile(session.accessToken, {
    fullName: 'Ayesha Khan',
    linkedinUrl: 'linkedin.com/ayesha',
    details: { university: '', skills: [], graduationYear: 1800 },
  });
  assert.equal(res.status, 400);
  const d = res.body.error.details;
  assert.equal(d.headline, 'Headline is required');
  assert.equal(d.city, 'City is required');
  assert.equal(d.linkedinUrl, 'Enter a full LinkedIn URL starting with https://');
  assert.equal(d['details.university'], 'University must be at least 2 characters');
  assert.equal(d['details.degreeProgram'], 'Degree program is required');
  assert.equal(d['details.skills'], 'Add at least one skill');
  assert.equal(d['details.graduationYear'], 'Enter a valid graduation year');
});

test('a complete owner profile is saved and marks the profile completed', async () => {
  const session = await loginAs('owner');
  const res = await putProfile(session.accessToken, {
    ...common,
    details: {
      university: 'SZABIST Karachi',
      degreeProgram: 'BS Computer Science',
      graduationYear: 2027,
      skills: ['Flutter', 'Node.js', 'Flutter'],
      githubUrl: 'https://github.com/ayesha',
      portfolioUrl: '',
    },
  });
  assert.equal(res.status, 200);
  assert.equal(res.body.profile.completed, true);
  assert.deepEqual(res.body.profile.details.skills, ['Flutter', 'Node.js']);   // duplicates removed
  assert.equal(res.body.profile.details.portfolioUrl, null);                    // empty → null

  const relogin = await api.post('/api/auth/refresh').send({ refreshToken: session.refreshToken });
  assert.equal(relogin.body.user.profileCompleted, true);
});

test('investor ranges and interests are checked', async () => {
  const session = await loginAs('investor');
  const base = { ...common, details: { investorType: 'angel', minTicket: 500000, maxTicket: 100000, interests: [] } };
  const bad = await putProfile(session.accessToken, base);
  assert.equal(bad.status, 400);
  assert.equal(bad.body.error.details['details.interests'], 'Choose at least one category');

  const badRange = await putProfile(session.accessToken,
    { ...base, details: { ...base.details, interests: [categories[0].id] } });
  assert.equal(badRange.body.error.details['details.maxTicket'],
    'Maximum investment must be greater than or equal to the minimum');

  const unknownCategory = await putProfile(session.accessToken, {
    ...base, details: { ...base.details, maxTicket: 900000, interests: ['00000000-0000-4000-8000-000000000000'] },
  });
  assert.equal(unknownCategory.status, 400);
  assert.equal(unknownCategory.body.error.details['details.interests'], 'One of the chosen categories no longer exists');
});

test('a complete investor profile saves interests', async () => {
  const session = await loginAs('investor');
  const res = await putProfile(session.accessToken, {
    ...common,
    details: {
      investorType: 'angel',
      organizationName: 'Karachi Angels',
      minTicket: 100000,
      maxTicket: 2000000,
      interests: [categories[0].id, categories[1].id],
    },
  });
  assert.equal(res.status, 200);
  assert.equal(res.body.profile.details.maxTicket, 2000000);
  assert.equal(res.body.profile.details.currency, 'PKR');
  assert.deepEqual(res.body.profile.details.interests.map(i => i.name), [categories[0].name, categories[1].name]);
});

test('a complete buyer profile is saved', async () => {
  const session = await loginAs('buyer');
  const res = await putProfile(session.accessToken, {
    ...common,
    details: {
      buyerType: 'small_business',
      companyName: 'Rehman Traders',
      companyWebsite: 'https://rehmantraders.pk',
      budgetMin: 50000,
      budgetMax: 300000,
      currency: 'PKR',
      interests: [categories[2].id],
    },
  });
  assert.equal(res.status, 200);
  assert.equal(res.body.profile.details.companyName, 'Rehman Traders');
  assert.equal(res.body.profile.completed, true);
});

test('admins have no role profile to fill in', async () => {
  const session = await loginAs('admin');
  assert.equal(session.user.profileCompleted, true);
  assert.equal((await putProfile(session.accessToken, common)).status, 403);
  assert.equal((await getProfile(session.accessToken)).body.profile.completed, true);
});
