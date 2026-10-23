// Tests for /api/listings, cover images, profile photos and signed file links.

process.env.NODE_ENV = 'test';

const { test, after, before } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');

const app = require('../src/app');
const { pool } = require('../src/db/pool');
const { createVerifiedUser, cleanup } = require('./helpers');

const api = request(app);
// smallest valid PNG (1×1 pixel)
const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', 'base64');
const SECRET_TEXT = 'Our secret revenue figures and full technical design';

let owner, otherOwner, investor, categoryId;

const login = async (role, options) => {
  const res = await api.post('/api/auth/login').send(await createVerifiedUser(role, undefined, options));
  return res.body.accessToken;
};
const as = token => ({
  get: url => api.get(url).set('Authorization', `Bearer ${token}`),
  post: (url, body) => api.post(url).set('Authorization', `Bearer ${token}`).send(body),
  put: (url, body) => api.put(url).set('Authorization', `Bearer ${token}`).send(body),
  del: url => api.delete(url).set('Authorization', `Bearer ${token}`),
  upload: (url, buffer, name) => api.put(url).set('Authorization', `Bearer ${token}`).attach('image', buffer, name),
});

const fundingListing = overrides => ({
  listingType: 'funding',
  categoryId,
  title: 'StudyBuddy — AI tutor for O Levels',
  shortDescription: 'A mobile app that helps O Level students practise past papers with instant feedback.',
  techStack: ['Flutter', 'Node.js', 'Flutter'],
  projectStage: 'mvp',
  askingAmount: 1500000,
  confidential: { fullDescription: SECRET_TEXT, equityOfferedPercent: 10, traction: '300 beta users' },
  ...overrides,
});
const saleListing = overrides => fundingListing({
  listingType: 'sale',
  title: 'Inventory app for small shops',
  confidential: { fullDescription: SECRET_TEXT, transferDetails: 'Full source code, database schema and one month of support.' },
  ...overrides,
});
const pathOf = url => { const u = new URL(url); return u.pathname + u.search; };

before(async () => {
  await cleanup();
  categoryId = (await api.get('/api/categories')).body.categories[0].id;
  owner = as(await login('owner', { approved: true }));
  otherOwner = as(await login('owner', { approved: true }));
  investor = as(await login('investor'));
});
after(async () => {
  await cleanup();
  await pool.end();
});

let fundingId, saleId;

test('an owner creates a funding draft; preview and confidential parts come back separately', async () => {
  const res = await owner.post('/api/listings', fundingListing());
  assert.equal(res.status, 201);
  assert.equal(res.body.listing.status, 'draft');
  assert.equal(res.body.listing.reviewStatus, 'unreviewed');
  assert.deepEqual(res.body.listing.techStack, ['Flutter', 'Node.js']);
  assert.equal(res.body.listing.askingAmount, 1500000);
  assert.equal(res.body.confidential.equityOfferedPercent, 10);
  assert.equal(res.body.listing.fullDescription, undefined, 'confidential fields never in the preview');
  fundingId = res.body.listing.id;
});

test('listing rules depend on the type', async () => {
  const noEquity = await owner.post('/api/listings', fundingListing({ confidential: { fullDescription: SECRET_TEXT } }));
  assert.equal(noEquity.status, 400);
  assert.equal(noEquity.body.error.details['confidential.equityOfferedPercent'], 'Equity offered is required for funding listings');

  const saleNoTransfer = await owner.post('/api/listings', saleListing({ confidential: { fullDescription: SECRET_TEXT, equityOfferedPercent: 5 } }));
  assert.equal(saleNoTransfer.body.error.details['confidential.transferDetails'], 'Describe what the buyer will receive');
  assert.equal(saleNoTransfer.body.error.details['confidential.equityOfferedPercent'], 'Equity applies only to funding listings');

  const shortFields = await owner.post('/api/listings', fundingListing({ title: 'AB', shortDescription: 'short', askingAmount: 0 }));
  assert.equal(shortFields.body.error.details.title, 'Title must be at least 3 characters');
  assert.equal(shortFields.body.error.details.shortDescription, 'Short description must be at least 10 characters');
  assert.equal(shortFields.body.error.details.askingAmount, 'Amount must be greater than 0');

  const badCategory = await owner.post('/api/listings', fundingListing({ categoryId: '00000000-0000-4000-8000-000000000000' }));
  assert.equal(badCategory.body.error.details.categoryId, 'This category no longer exists');
});

test('an owner waiting for approval can create drafts but not publish', async () => {
  const pendingOwner = as(await login('owner'));
  const draft = await pendingOwner.post('/api/listings', fundingListing());
  assert.equal(draft.status, 201);
  const publish = await pendingOwner.post(`/api/listings/${draft.body.listing.id}/publish`);
  assert.equal(publish.status, 403);
  assert.equal(publish.body.error.code, 'ACCOUNT_NOT_APPROVED');
});

test('amounts are in PKR only', async () => {
  const res = await owner.post('/api/listings', fundingListing({ currency: 'USD' }));
  assert.equal(res.body.error.details.currency, 'Amounts are in PKR');
});

test('only project owners can create listings', async () => {
  assert.equal((await investor.post('/api/listings', fundingListing())).status, 403);
  assert.equal((await api.post('/api/listings').send(fundingListing())).status, 401);
});

test('a sale listing is created and "my listings" shows only my own', async () => {
  const sale = await owner.post('/api/listings', saleListing());
  assert.equal(sale.status, 201);
  saleId = sale.body.listing.id;
  await otherOwner.post('/api/listings', fundingListing({ title: 'Someone else project' }));

  const mine = await owner.get('/api/listings/mine');
  assert.deepEqual(mine.body.listings.map(l => l.id).sort(), [fundingId, saleId].sort());
});

test('drafts are invisible to everyone except their owner', async () => {
  assert.equal((await otherOwner.get(`/api/listings/${fundingId}`)).status, 404);
  assert.equal((await investor.get(`/api/listings/${fundingId}`)).status, 404);
  assert.equal((await otherOwner.put(`/api/listings/${fundingId}`, fundingListing())).status, 404);
  assert.equal((await otherOwner.post(`/api/listings/${fundingId}/publish`)).status, 404);
  assert.equal((await owner.get('/api/listings/not-a-uuid')).status, 404);
});

test('publishing sends the listing for review', async () => {
  const res = await owner.post(`/api/listings/${fundingId}/publish`);
  assert.equal(res.status, 200);
  assert.equal(res.body.listing.status, 'published');
  assert.equal(res.body.listing.reviewStatus, 'pending');
  assert.ok(res.body.listing.publishedAt);
  assert.equal((await owner.post(`/api/listings/${fundingId}/publish`)).status, 409);
});

test('a published listing stays hidden from others until an admin approves it', async () => {
  assert.equal((await investor.get(`/api/listings/${fundingId}`)).status, 404);
  await pool.query("UPDATE listings SET review_status = 'approved' WHERE id = $1", [fundingId]);
});

test('others see only the public preview of an approved listing', async () => {
  const res = await investor.get(`/api/listings/${fundingId}`);
  assert.equal(res.status, 200);
  assert.equal(res.body.listing.title, 'StudyBuddy — AI tutor for O Levels');
  assert.equal(res.body.confidential, undefined);
  assert.ok(!JSON.stringify(res.body).includes(SECRET_TEXT), 'confidential text must not leak');
});

test('editing a published listing sends it back for review; its type cannot change', async () => {
  const edited = await owner.put(`/api/listings/${fundingId}`, fundingListing({ askingAmount: 2000000 }));
  assert.equal(edited.status, 200);
  assert.equal(edited.body.listing.askingAmount, 2000000);
  assert.equal(edited.body.listing.reviewStatus, 'pending');

  const typeChange = await owner.put(`/api/listings/${fundingId}`, saleListing());
  assert.equal(typeChange.body.error.details.listingType, 'The listing type can only be changed while the listing is a draft');
});

test('unpublish, close and delete follow the allowed status moves', async () => {
  assert.equal((await owner.post(`/api/listings/${fundingId}/unpublish`)).body.listing.status, 'draft');
  assert.equal((await owner.post(`/api/listings/${fundingId}/close`)).body.listing.status, 'closed');
  assert.equal((await owner.put(`/api/listings/${fundingId}`, fundingListing())).body.error.code, 'LISTING_CLOSED');
  assert.equal((await owner.del(`/api/listings/${fundingId}`)).status, 409, 'closed listings are kept');

  assert.equal((await owner.del(`/api/listings/${saleId}`)).status, 204);
  assert.equal((await owner.get(`/api/listings/${saleId}`)).status, 404);
});

test('a cover image is stored privately and served through an expiring signed link', async () => {
  const draft = (await owner.post('/api/listings', fundingListing())).body.listing.id;
  const res = await owner.upload(`/api/listings/${draft}/cover`, PNG, 'cover.png');
  assert.equal(res.status, 200);
  const url = res.body.listing.coverUrl;
  assert.match(url, /\/api\/files\/listings\/.+\?expires=\d+&sig=/);

  const image = await api.get(pathOf(url));
  assert.equal(image.status, 200);
  assert.equal(image.headers['content-type'], 'image/png');

  assert.equal((await api.get(pathOf(url).replace(/sig=[^&]+/, 'sig=forged'))).status, 403);
  assert.equal((await api.get(pathOf(url).replace(/expires=\d+/, 'expires=1'))).status, 403);

  const notImage = await owner.upload(`/api/listings/${draft}/cover`, Buffer.from('hello'), 'fake.png');
  assert.equal(notImage.status, 400);
  assert.equal(notImage.body.error.details.image, 'Only JPEG, PNG or WebP images are allowed');

  assert.equal((await otherOwner.upload(`/api/listings/${draft}/cover`, PNG, 'x.png')).status, 404);
  assert.equal((await owner.del(`/api/listings/${draft}/cover`)).body.listing.coverUrl, null);
});

test('profile photo can be set and removed', async () => {
  const set = await investor.upload('/api/profile/me/avatar', PNG, 'me.png');
  assert.equal(set.status, 200);
  assert.match(set.body.profile.avatarUrl, /\/api\/files\/avatars\//);
  assert.equal((await api.get(pathOf(set.body.profile.avatarUrl))).status, 200);

  const removed = await investor.del('/api/profile/me/avatar');
  assert.equal(removed.body.profile.avatarUrl, null);
});
