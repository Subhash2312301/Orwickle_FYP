// Tests for /api/profile/me, verification documents and /api/categories against the real database.

process.env.NODE_ENV = 'test';

const { test, after, before } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');

const app = require('../src/app');
const { pool } = require('../src/db/pool');
const { createVerifiedUser, cleanup } = require('./helpers');

const api = request(app);
// smallest valid PNG (1×1 pixel) and a minimal PDF header
const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', 'base64');
const PDF = Buffer.from('%PDF-1.4\n%sample certificate\n');
let categories;

async function loginAs(role, name) {
  const creds = await createVerifiedUser(role, name);
  const res = await api.post('/api/auth/login').send(creds);
  assert.equal(res.status, 200);
  return res.body;
}
const auth = token => ['Authorization', `Bearer ${token}`];
const getProfile = token => api.get('/api/profile/me').set(...auth(token));
const putProfile = (token, body) => api.put('/api/profile/me').set(...auth(token)).send(body);
const upload = (token, kind, file = PNG, name = 'doc.png') =>
  api.put(`/api/profile/me/documents/${kind}`).set(...auth(token)).attach('file', file, name);

const ownerBody = {
  fullName: 'Ayesha Khan',
  headline: 'Final-year CS student building EdTech apps',
  city: 'Karachi',
  linkedinUrl: 'https://www.linkedin.com/in/ayesha',
  details: {
    isStudent: true,
    university: 'SZABIST Karachi',
    degreeProgram: 'BS Computer Science',
    skills: ['Flutter', 'Node.js', 'Flutter'],
    githubUrl: 'https://github.com/ayesha',
    portfolioUrl: 'https://ayesha.dev',
  },
};
const investorBody = overrides => ({
  fullName: 'Farhan Malik',
  city: 'Karachi',
  phone: '0300-1234567',
  linkedinUrl: 'https://www.linkedin.com/in/farhan',
  details: {
    investorType: 'angel',
    cnicNumber: '42101-1234567-1',
    investmentExperience: '1_3',
    minTicket: 500000,
    maxTicket: 2000000,
    interests: [categories[0].id, categories[1].id],
    ...overrides,
  },
});
const buyerBody = overrides => ({
  fullName: 'Imran Sheikh',
  city: 'Karachi',
  details: { buyerType: 'small_business', affiliation: 'company', companyName: 'Sheikh Traders', interests: [categories[2].id], ...overrides },
});

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
  assert.equal((await api.put('/api/profile/me').send(ownerBody)).status, 401);
});

test('a new owner starts with an incomplete profile', async () => {
  const session = await loginAs('owner', 'Ayesha Khan');
  assert.equal(session.user.profileCompleted, false);
  const res = await getProfile(session.accessToken);
  assert.equal(res.body.profile.completed, false);
  assert.deepEqual(res.body.profile.details.skills, []);
  assert.deepEqual(res.body.profile.documents, []);
});

test('owner fields are validated one by one', async () => {
  const session = await loginAs('owner');
  const res = await putProfile(session.accessToken, {
    fullName: 'Ayesha Khan',
    linkedinUrl: 'linkedin.com/ayesha',
    details: { skills: [], portfolioUrl: '' },
  });
  assert.equal(res.status, 400);
  const d = res.body.error.details;
  assert.equal(d.headline, 'Headline is required');
  assert.equal(d.city, 'City is required');
  assert.equal(d.linkedinUrl, 'Enter a full LinkedIn profile starting with https://');
  assert.equal(d['details.isStudent'], 'Choose whether you are a university student');
  assert.equal(d['details.skills'], 'Add at least one skill');
  assert.equal(d['details.githubUrl'], 'GitHub profile is required');
  assert.equal(d['details.portfolioUrl'], 'Portfolio link is required');

  const student = await putProfile(session.accessToken, { ...ownerBody, details: { ...ownerBody.details, university: '' } });
  assert.equal(student.body.error.details['details.university'], 'University is required for students');
});

test('an independent developer needs no university, degree or university ID', async () => {
  const session = await loginAs('owner');
  const independent = { ...ownerBody, details: { ...ownerBody.details, isStudent: false, university: '', degreeProgram: '' } };
  const saved = await putProfile(session.accessToken, independent);
  assert.equal(saved.status, 200);
  assert.equal(saved.body.profile.reviewStatus, 'pending');
  assert.equal(saved.body.profile.details.isStudent, false);
  assert.equal(saved.body.profile.details.university, null);
});

test('an owner must upload both sides of the university ID card', async () => {
  const session = await loginAs('owner');
  const missing = await putProfile(session.accessToken, ownerBody);
  assert.equal(missing.status, 400);
  assert.equal(missing.body.error.details['documents.university_id_front'], 'Upload the front of your university ID card');
  assert.equal(missing.body.error.details['documents.university_id_back'], 'Upload the back of your university ID card');

  assert.equal((await upload(session.accessToken, 'university_id_front')).status, 200);
  const back = await upload(session.accessToken, 'university_id_back');
  assert.deepEqual(back.body.profile.documents.map(d => d.kind).sort(), ['university_id_back', 'university_id_front']);
  assert.match(back.body.profile.documents[0].url, /\/api\/files\/documents\//);

  const saved = await putProfile(session.accessToken, ownerBody);
  assert.equal(saved.status, 200);
  assert.equal(saved.body.profile.completed, true);
  assert.equal(saved.body.profile.reviewStatus, 'pending');
  assert.deepEqual(saved.body.profile.details.skills, ['Flutter', 'Node.js']);
});

test('documents are checked: right kind for the role, image or PDF only', async () => {
  const owner = await loginAs('owner');
  const wrongKind = await upload(owner.accessToken, 'cnic_front');
  assert.equal(wrongKind.body.error.details.kind, 'This document is not needed for your role');

  const investor = await loginAs('investor');
  const text = await upload(investor.accessToken, 'cnic_front', Buffer.from('hello'), 'x.png');
  assert.equal(text.body.error.details.file, 'Only JPEG, PNG, WebP or PDF files are allowed');
  assert.equal((await upload(investor.accessToken, 'company_certificate', PDF, 'cert.pdf')).status, 200);
});

test('investor: phone, CNIC, LinkedIn, experience and range are required', async () => {
  const session = await loginAs('investor');
  const res = await putProfile(session.accessToken, { fullName: 'Farhan Malik', city: 'Karachi', details: { investorType: 'angel' } });
  const d = res.body.error.details;
  assert.equal(d.phone, 'Phone number is required');
  assert.equal(d.linkedinUrl, 'LinkedIn profile is required');
  assert.equal(d['details.cnicNumber'], 'CNIC number is required');
  assert.equal(d['details.investmentExperience'], 'Choose your investment experience');
  assert.equal(d['details.minTicket'], 'Choose an investment range');

  const badFormats = await putProfile(session.accessToken, {
    ...investorBody(), phone: '12345', details: { ...investorBody().details, cnicNumber: '123' },
  });
  assert.equal(badFormats.body.error.details.phone, 'Enter a mobile number like 03001234567');
  assert.equal(badFormats.body.error.details['details.cnicNumber'], 'Enter the 13-digit CNIC number, e.g. 42101-1234567-1');
});

test('an angel investor proves identity, funds and a past investment, but needs no company details', async () => {
  const session = await loginAs('investor');
  const missing = await putProfile(session.accessToken, investorBody());
  const d = missing.body.error.details;
  assert.equal(d['documents.cnic_front'], 'Upload the front of your CNIC');
  assert.equal(d['documents.funds_proof'], 'Upload proof of funds (bank statement, bank letter or tax return)');
  assert.equal(d['documents.investment_proof'],
    'Upload proof of a past investment (share certificate, investment agreement or letter from the startup)');
  assert.equal(d['documents.company_certificate'], undefined);

  for (const kind of ['cnic_front', 'cnic_back', 'investment_proof']) await upload(session.accessToken, kind);
  await upload(session.accessToken, 'funds_proof', PDF, 'statement.pdf');
  const withWebsite = { ...investorBody(), websiteUrl: 'https://farhan.pk' };
  const saved = await putProfile(session.accessToken, withWebsite);
  assert.equal(saved.status, 200);
  const p = saved.body.profile;
  assert.equal(p.phone, '03001234567', 'phone normalised');
  assert.equal(p.websiteUrl, 'https://farhan.pk', 'investors may add a website');
  assert.equal(p.details.cnicNumber, '4210112345671', 'CNIC stored as 13 digits');
  assert.equal(p.details.maxTicket, 2000000);
  assert.equal(p.reviewStatus, 'pending');

  // first-time investors have no past investment to prove; the old proof is removed
  const firstTime = await putProfile(session.accessToken, investorBody({ investmentExperience: 'first_time' }));
  assert.equal(firstTime.status, 200);
  assert.deepEqual(firstTime.body.profile.documents.map(x => x.kind).sort(), ['cnic_back', 'cnic_front', 'funds_proof']);
});

test('an investment firm must give company details and the registration certificate', async () => {
  const session = await loginAs('investor');
  await upload(session.accessToken, 'cnic_front');
  await upload(session.accessToken, 'cnic_back');
  const res = await putProfile(session.accessToken, investorBody({ investorType: 'firm' }));
  const d = res.body.error.details;
  assert.equal(d['details.companyName'], 'Company name is required for investment firms');
  assert.equal(d['details.companyWebsite'], 'Company website is required for investment firms');
  assert.equal(d['details.companyEmail'], 'Company email is required for investment firms');

  const firm = investorBody({
    investorType: 'firm', companyName: 'Karachi Seed Ventures', companyWebsite: 'https://ksv.pk', companyEmail: 'deals@ksv.pk',
  });
  const noCertificate = await putProfile(session.accessToken, firm);
  assert.equal(noCertificate.body.error.details['documents.company_certificate'], 'Upload your company registration certificate');
  assert.equal(noCertificate.body.error.details['documents.funds_proof'], undefined, 'the certificate replaces proof of funds');

  await upload(session.accessToken, 'company_certificate', PDF, 'cert.pdf');
  await upload(session.accessToken, 'investment_proof', PDF, 'agreement.pdf');
  const saved = await putProfile(session.accessToken, firm);
  assert.equal(saved.status, 200);
  assert.equal(saved.body.profile.details.companyEmail, 'deals@ksv.pk');
});

test('a buyer from a company gives the company name; no budget, headline or website', async () => {
  const session = await loginAs('buyer');
  const missing = await putProfile(session.accessToken, buyerBody({ companyName: '' }));
  assert.equal(missing.body.error.details['details.companyName'], 'Company name is required');

  const saved = await putProfile(session.accessToken, { ...buyerBody(), headline: 'ignored', websiteUrl: 'https://ignored.pk' });
  assert.equal(saved.status, 200);
  const p = saved.body.profile;
  assert.equal(p.details.companyName, 'Sheikh Traders');
  assert.equal(p.details.budgetMin, undefined);
  assert.equal(p.headline, null);
  assert.equal(p.websiteUrl, null);
});

test('a buyer from a university uploads the university ID card instead', async () => {
  const session = await loginAs('buyer');
  const body = buyerBody({ affiliation: 'university', companyName: null });
  const missing = await putProfile(session.accessToken, body);
  assert.equal(missing.body.error.details['documents.university_id_front'], 'Upload the front of your university ID card');

  await upload(session.accessToken, 'university_id_front');
  await upload(session.accessToken, 'university_id_back');
  const saved = await putProfile(session.accessToken, body);
  assert.equal(saved.status, 200);
  assert.equal(saved.body.profile.details.affiliation, 'university');
});

test('changing a document of an approved account sends it back for review', async () => {
  const session = await loginAs('owner');
  await upload(session.accessToken, 'university_id_front');
  await upload(session.accessToken, 'university_id_back');
  await putProfile(session.accessToken, ownerBody);
  await pool.query(`UPDATE profiles SET review_status = 'approved' WHERE user_id = $1`, [session.user.id]);

  const replaced = await upload(session.accessToken, 'university_id_front');
  assert.equal(replaced.body.profile.reviewStatus, 'pending');
  assert.equal(replaced.body.profile.documents.length, 2, 'the old file was replaced, not added');
});

test('admins have no role profile to fill in', async () => {
  const session = await loginAs('admin');
  assert.equal(session.user.profileCompleted, true);
  assert.equal(session.user.approvalStatus, 'approved');
  assert.equal((await putProfile(session.accessToken, ownerBody)).status, 403);
});
