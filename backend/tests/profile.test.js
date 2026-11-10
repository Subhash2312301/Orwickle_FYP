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
const link = (token, kind, url) => api.put(`/api/profile/me/documents/${kind}/link`).set(...auth(token)).send({ url });

const ownerBody = {
  fullName: 'Ayesha Khan',
  headline: 'Final-year CS student building EdTech apps',
  bio: 'I build learning apps for O Level students.',
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
  linkedinUrl: 'https://www.linkedin.com/in/farhan',
  details: {
    organization: 'Karachi Seed Ventures',
    designation: 'Managing Partner',
    companyWebsite: 'https://ksv.pk',
    investmentInterests: 'Student-built SaaS and EdTech products with early users.',
    investmentStages: ['mvp', 'launched', 'mvp'],
    minTicket: 500000,
    maxTicket: 2000000,
    interests: [categories[0].id, categories[1].id],
    ...overrides,
  },
});
const buyerBody = overrides => ({
  fullName: 'Imran Sheikh',
  city: 'Karachi',
  phone: '03211234567',
  linkedinUrl: 'https://www.linkedin.com/in/imran',
  details: {
    buyerType: 'small_business', affiliation: 'company', companyName: 'Sheikh Traders', companyEmail: 'Imran@Sheikh.pk',
    interests: [categories[2].id], ...overrides,
  },
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
  assert.equal(d.bio, 'Bio is required');
  assert.equal(d.city, undefined, 'owners have no city');
  assert.equal(d.linkedinUrl, 'Enter a full LinkedIn profile starting with https://');
  assert.equal(d['details.isStudent'], 'Choose whether you are a university student');
  assert.equal(d['details.skills'], 'Add at least one skill');
  assert.equal(d['details.githubUrl'], 'GitHub profile is required');
  assert.equal(d['details.portfolioUrl'], 'Portfolio link is required');

  const student = await putProfile(session.accessToken, { ...ownerBody, details: { ...ownerBody.details, university: '' } });
  assert.equal(student.body.error.details['details.university'], 'University is required for students');
});

test('an independent developer gives the CNIC instead of university, degree and university ID', async () => {
  const session = await loginAs('owner');
  const independent = { ...ownerBody, details: { ...ownerBody.details, isStudent: false, university: '', degreeProgram: '' } };
  const missing = await putProfile(session.accessToken, independent);
  assert.equal(missing.body.error.details['documents.cnic_front'], 'Upload the front of your CNIC');
  assert.equal(missing.body.error.details['documents.cnic_back'], 'Upload the back of your CNIC');
  assert.equal(missing.body.error.details['documents.university_id_front'], undefined);

  await upload(session.accessToken, 'cnic_front');
  await upload(session.accessToken, 'cnic_back');
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

test('documents are checked: right kind for the role, image or PDF only, links for investor evidence only', async () => {
  const owner = await loginAs('owner');
  const wrongKind = await upload(owner.accessToken, 'company_registration');
  assert.equal(wrongKind.body.error.details.kind, 'This document is not needed for your role');
  assert.equal((await link(owner.accessToken, 'cnic_front', 'https://x.pk')).status, 403, 'owners give files, not links');

  const investor = await loginAs('investor');
  const text = await upload(investor.accessToken, 'company_registration', Buffer.from('hello'), 'x.png');
  assert.equal(text.body.error.details.file, 'Only JPEG, PNG, WebP or PDF files are allowed');
  assert.equal((await upload(investor.accessToken, 'company_registration', PDF, 'cert.pdf')).status, 200);
  const cnic = await upload(investor.accessToken, 'cnic_front');
  assert.equal(cnic.body.error.details.kind, 'This document is not needed for your role', 'investors give no CNIC');
  const badLink = await link(investor.accessToken, 'investment_portfolio', 'angel.co/farhan');
  assert.equal(badLink.body.error.details.url, 'Enter a full Link starting with https://');
});

test('investor: organization, designation, LinkedIn, interests, stages, range and sectors are required; no CNIC or phone', async () => {
  const session = await loginAs('investor');
  const res = await putProfile(session.accessToken, { fullName: 'Farhan Malik', details: {} });
  const d = res.body.error.details;
  assert.equal(d.linkedinUrl, 'LinkedIn profile is required');
  assert.equal(d['details.organization'], 'Organization or company is required');
  assert.equal(d['details.designation'], 'Professional designation is required');
  assert.equal(d['details.investmentInterests'], 'Investment interests is required');
  assert.equal(d['details.investmentStages'], 'Investment stages is required');
  assert.equal(d['details.minTicket'], 'Choose an investment range');
  assert.equal(d['details.interests'], 'Interests is required');
  for (const gone of ['phone', 'city', 'details.cnicNumber', 'details.investorType', 'details.investmentExperience']) {
    assert.equal(d[gone], undefined, `${gone} is no longer asked`);
  }

  const noStage = await putProfile(session.accessToken, investorBody({ investmentStages: [], companyWebsite: 'ksv.pk' }));
  assert.equal(noStage.body.error.details['details.investmentStages'], 'Choose at least one stage');
  assert.equal(noStage.body.error.details['details.companyWebsite'], 'Enter a full company website starting with https://');

  // names and titles take letters, not numbers or symbols; an organization may contain numbers
  const symbols = await putProfile(session.accessToken, {
    ...investorBody({ organization: '@@##', designation: 'Manager 123' }),
    fullName: 'Farhan 99',
  });
  const s = symbols.body.error.details;
  assert.equal(s.fullName, "Full name can only contain letters, spaces and . ' -");
  assert.equal(s['details.designation'], "Professional designation can only contain letters, spaces and . , & - / ( ) '");
  assert.equal(s['details.organization'], "Organization or company can only contain letters, numbers, spaces and . , & - / ( ) '");
  const numbersOk = await putProfile(session.accessToken, investorBody({ organization: '500 Startups', designation: 'Co-Founder & CEO' }));
  assert.equal(numbersOk.body.error.details['details.organization'], undefined);
  assert.equal(numbersOk.body.error.details['details.designation'], undefined);
});

test('an owner headline and a buyer city refuse numbers and symbols', async () => {
  const owner = await loginAs('owner');
  const badHeadline = await putProfile(owner.accessToken, { ...ownerBody, headline: 'Developer #1 @ 2026' });
  assert.equal(badHeadline.body.error.details.headline, "Headline can only contain letters, spaces and . , & - / ( ) '");
  const buyer = await loginAs('buyer');
  const badCity = await putProfile(buyer.accessToken, { ...buyerBody(), city: 'Karachi 75500' });
  assert.equal(badCity.body.error.details.city, "City can only contain letters, spaces and . ' -");
});

test('an investor needs at least two pieces of supporting evidence, each a file or a link', async () => {
  const session = await loginAs('investor');
  const none = await putProfile(session.accessToken, investorBody());
  assert.equal(none.status, 400);
  assert.equal(none.body.error.details.documents, 'Add at least 2 pieces of supporting evidence');

  await upload(session.accessToken, 'company_registration', PDF, 'registration.pdf');
  const one = await putProfile(session.accessToken, investorBody());
  assert.equal(one.body.error.details.documents, 'Add at least 2 pieces of supporting evidence');

  const linked = await link(session.accessToken, 'investment_portfolio', 'https://angel.co/farhan');
  assert.equal(linked.status, 200);
  const portfolio = linked.body.profile.documents.find(x => x.kind === 'investment_portfolio');
  assert.equal(portfolio.isLink, true);
  assert.equal(portfolio.url, 'https://angel.co/farhan');

  const saved = await putProfile(session.accessToken, { ...investorBody(), city: 'ignored', phone: '03001234567' });
  assert.equal(saved.status, 200);
  const p = saved.body.profile;
  assert.equal(p.reviewStatus, 'pending');
  assert.equal(p.details.organization, 'Karachi Seed Ventures');
  assert.equal(p.details.designation, 'Managing Partner');
  assert.equal(p.details.companyWebsite, 'https://ksv.pk');
  assert.deepEqual(p.details.investmentStages, ['mvp', 'launched'], 'duplicates removed');
  assert.equal(p.details.maxTicket, 2000000);
  assert.equal(p.details.cnicNumber, undefined);
  assert.equal(p.phone, null, 'investors give no phone');
  assert.equal(p.city, null, 'investors give no city');
  assert.deepEqual(p.documents.map(x => x.kind).sort(), ['company_registration', 'investment_portfolio']);

  // replacing the link keeps one item of that kind
  const replaced = await link(session.accessToken, 'investment_portfolio', 'https://www.crunchbase.com/person/farhan');
  assert.equal(replaced.body.profile.documents.length, 2);
});

test('a buyer from a company gives phone, LinkedIn, company name and email; no budget, headline or website', async () => {
  const session = await loginAs('buyer');
  const missing = await putProfile(session.accessToken, {
    fullName: 'Imran Sheikh', city: 'Karachi',
    details: { ...buyerBody().details, companyName: '', companyEmail: '' },
  });
  const d = missing.body.error.details;
  assert.equal(d['details.companyName'], 'Company name is required');
  assert.equal(d['details.companyEmail'], 'Company email is required');
  assert.equal(d.phone, 'Phone number is required');
  assert.equal(d.linkedinUrl, 'LinkedIn profile is required');

  const saved = await putProfile(session.accessToken, { ...buyerBody(), headline: 'ignored', websiteUrl: 'https://ignored.pk' });
  assert.equal(saved.status, 200);
  const p = saved.body.profile;
  assert.equal(p.details.companyName, 'Sheikh Traders');
  assert.equal(p.details.companyEmail, 'imran@sheikh.pk');
  assert.equal(p.phone, '03211234567');
  assert.equal(p.linkedinUrl, 'https://www.linkedin.com/in/imran');
  assert.equal(p.details.budgetMin, undefined);
  assert.equal(p.headline, null);
  assert.equal(p.websiteUrl, null);
});

test('a buyer from a university uploads the university ID card instead', async () => {
  const session = await loginAs('buyer');
  const body = buyerBody({ affiliation: 'university', companyName: null, companyEmail: null });
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
