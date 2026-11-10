// Mock of the Orwickle admin API (same response shapes as backend/src/modules/admin), for screenshots only.
// node tools/screenshots/mock_api.cjs 4100
const http = require('http');

const port = Number(process.argv[2] || 4100);
const day = (n, h = 10, m = 0) => new Date(Date.UTC(2026, 10, n, h - 5, m)).toISOString(); // Nov 2026, PKT

const admin = { id: 'a0000000-0000-4000-8000-000000000001', email: 'subhash@gmail.com', role: 'admin', fullName: 'Subhash Rai', emailVerified: true, profileCompleted: true, approvalStatus: 'approved' };

const cats = names => names.map((name, i) => ({ id: 'c' + i, name }));
const pdf = (id, kind, at) => ({ id, kind, url: 'about:blank', isLink: false, contentType: 'application/pdf', uploadedAt: at });
const link = (id, kind, url, at) => ({ id, kind, url, isLink: true, contentType: null, uploadedAt: at });

// role details and documents per person
const people = [
  {
    id: 'u3', role: 'investor', fullName: 'Bilal Ahmed', email: 'bilal.ahmed@gmail.com', reviewStatus: 'pending', at: day(8, 11),
    linkedinUrl: 'https://www.linkedin.com/in/bilal-ahmed',
    details: {
      organization: 'Lahore Angel Network', designation: 'Angel Investor', companyWebsite: 'https://lahoreangels.pk',
      investmentInterests: 'Student-built products with early users in agriculture, education and payments.',
      investmentStages: ['prototype', 'mvp'], minTicket: 500000, maxTicket: 2000000, interests: cats(['AgriTech', 'EdTech', 'FinTech']),
    },
    documents: [
      link('e1', 'network_affiliation', 'https://lahoreangels.pk/members/bilal-ahmed', day(8, 11, 20)),
      link('e2', 'investment_portfolio', 'https://angel.co/u/bilal-ahmed', day(8, 11, 22)),
      pdf('e3', 'professional_credential', day(8, 11, 25)),
    ],
  },
  {
    id: 'u9', role: 'investor', fullName: 'Omar Farooq', email: 'omar.farooq@gmail.com', reviewStatus: 'pending', at: day(9, 16),
    linkedinUrl: 'https://www.linkedin.com/in/omar-farooq',
    details: {
      organization: 'Indus Seed Fund', designation: 'Managing Partner', companyWebsite: 'https://indusseed.pk',
      investmentInterests: 'SaaS and logistics tools for small businesses in Pakistan.',
      investmentStages: ['mvp', 'launched'], minTicket: 2000000, maxTicket: 10000000, interests: cats(['SaaS', 'Logistics']),
    },
    documents: [pdf('e4', 'company_registration', day(9, 16, 10)), link('e5', 'accelerator_affiliation', 'https://nic.pk/mentors', day(9, 16, 12))],
  },
  {
    id: 'u4', role: 'investor', fullName: 'Fatima Noor', email: 'fatima.noor@gmail.com', reviewStatus: 'approved', at: day(2),
    linkedinUrl: 'https://www.linkedin.com/in/fatima-noor',
    details: {
      organization: 'Karachi Ventures', designation: 'Investment Associate', companyWebsite: 'https://karachiventures.pk',
      investmentInterests: 'HealthTech and EdTech apps.', investmentStages: ['mvp'], minTicket: 500000, maxTicket: 2000000,
      interests: cats(['HealthTech', 'EdTech']),
    },
    documents: [pdf('e6', 'company_registration', day(2, 12)), link('e7', 'investment_portfolio', 'https://www.crunchbase.com/person/fatima-noor', day(2, 12))],
  },
  {
    id: 'u10', role: 'investor', fullName: 'Sana Iqbal', email: 'sana.iqbal@gmail.com', reviewStatus: 'expired', at: day(1),
    reviewNote: 'Please add your angel network membership.', linkedinUrl: 'https://www.linkedin.com/in/sana-iqbal',
    details: { organization: 'Independent', designation: 'Angel Investor', companyWebsite: null, investmentInterests: 'Consumer apps.', investmentStages: ['idea'], minTicket: 100000, maxTicket: 500000, interests: cats(['E-commerce']) },
    documents: [link('e8', 'investment_portfolio', 'https://angel.co/u/sana-iqbal', day(1, 13))],
  },
  {
    id: 'u8', role: 'investor', fullName: 'Maryam Shah', email: 'maryam.shah@gmail.com', reviewStatus: 'rejected', at: day(3), status: 'suspended',
    reviewNote: 'The network membership page does not list you.', linkedinUrl: 'https://www.linkedin.com/in/maryam-shah',
    details: { organization: 'Shah Capital', designation: 'Partner', companyWebsite: null, investmentInterests: 'Any sector.', investmentStages: ['idea', 'prototype'], minTicket: 100000, maxTicket: 500000, interests: cats(['FinTech']) },
    documents: [link('e9', 'network_affiliation', 'https://angels.example/shah', day(3, 12)), pdf('e10', 'company_registration', day(3, 12))],
  },
  {
    id: 'u2', role: 'owner', fullName: 'Hamza Ali', email: 'hamza.ali@gmail.com', reviewStatus: 'pending', at: day(9, 14),
    linkedinUrl: 'https://www.linkedin.com/in/hamza-ali', headline: 'CS student building AgriTech hardware',
    bio: 'Final-year student at SZABIST. I build low-cost IoT devices and the apps that run them.',
    details: { isStudent: true, university: 'SZABIST Karachi', degreeProgram: 'BS Computer Science', skills: ['Flutter', 'Node.js', 'PostgreSQL', 'IoT'], githubUrl: 'https://github.com/hamzaali', portfolioUrl: 'https://hamzaali.dev' },
    documents: [pdf('d1', 'university_id_front', day(9, 14, 5)), pdf('d2', 'university_id_back', day(9, 14, 6))],
  },
  {
    id: 'u1', role: 'owner', fullName: 'Ayesha Khan', email: 'ayesha.khan@gmail.com', reviewStatus: 'approved', at: day(1),
    linkedinUrl: 'https://www.linkedin.com/in/ayesha-khan', headline: 'Building EdTech apps', bio: 'Student developer.',
    details: { isStudent: true, university: 'FAST Karachi', degreeProgram: 'BS Software Engineering', skills: ['React'], githubUrl: 'https://github.com/ayeshakhan', portfolioUrl: 'https://ayesha.dev' },
    documents: [],
  },
  {
    id: 'u7', role: 'owner', fullName: 'Daniyal Akram', email: 'daniyal.akram@gmail.com', reviewStatus: 'approved', at: day(2),
    linkedinUrl: 'https://www.linkedin.com/in/daniyal-akram', headline: 'Full-stack developer', bio: 'Self-taught developer building tools for clinics.',
    details: { isStudent: false, university: null, degreeProgram: null, skills: ['React', 'Express', 'PostgreSQL'], githubUrl: 'https://github.com/daniyalakram', portfolioUrl: 'https://daniyal.dev' },
    documents: [],
  },
  {
    id: 'u6', role: 'buyer', fullName: 'Zainab Hussain', email: 'zainab.hussain@gmail.com', reviewStatus: 'needs_evidence', at: day(6),
    reviewNote: 'Please upload a clearer photo of your university ID.', linkedinUrl: 'https://www.linkedin.com/in/zainab-hussain',
    city: 'Islamabad', phone: '03001234567',
    details: { buyerType: 'small_business', affiliation: 'university', companyName: null, companyEmail: null, interests: cats(['HealthTech', 'E-commerce']) },
    documents: [pdf('d3', 'university_id_front', day(6, 12)), pdf('d4', 'university_id_back', day(6, 12))],
  },
  {
    id: 'u5', role: 'buyer', fullName: 'Usman Tariq', email: 'usman.tariq@gmail.com', reviewStatus: 'approved', at: day(4),
    linkedinUrl: 'https://www.linkedin.com/in/usman-tariq', city: 'Karachi', phone: '03211234567',
    details: { buyerType: 'agency', affiliation: 'company', companyName: 'Tariq Digital', companyEmail: 'usman@tariqdigital.pk', interests: cats(['SaaS']) },
    documents: [],
  },
];
const byId = id => people.find(p => p.id === id);

const listUser = p => ({
  id: p.id, email: p.email, role: p.role, fullName: p.fullName, status: p.status || 'active', reviewStatus: p.reviewStatus,
  emailVerified: true, locked: false, isSample: false, registeredAt: p.at,
});

const profileOf = p => ({
  role: p.role, email: p.email, fullName: p.fullName, avatarUrl: null, headline: p.headline ?? null, bio: p.bio ?? null,
  city: p.city ?? null, phone: p.phone ?? null, linkedinUrl: p.linkedinUrl, websiteUrl: null,
  reviewStatus: p.reviewStatus, reviewNote: p.reviewNote ?? null, reviewedAt: null, completedDealCount: 0, completed: true,
  isSample: false, details: p.details, documents: p.documents,
});

const reviewed = (decision, reason, docs, at) => ({
  decision, reason, checklist: {}, reviewer: 'Subhash Rai', at,
  evidenceReviewed: docs.map(d => ({ id: d.id, kind: d.kind, link: d.isLink ? d.url : null, file: !d.isLink, addedAt: d.uploadedAt })),
});
const decisionsOf = {
  u4: [reviewed('approve', 'Approved', byId('u4').documents, day(3, 15, 10))],
  u10: [reviewed('request_more', 'Please add your angel network membership.', byId('u10').documents, day(2, 12))],
  u8: [
    reviewed('suspend', 'Fake investment documents', byId('u8').documents, day(5, 12)),
    reviewed('reject', 'The network membership page does not list you.', byId('u8').documents, day(4, 17)),
  ],
  u6: [reviewed('request_more', 'Please upload a clearer photo of your university ID.', byId('u6').documents, day(7, 10))],
  u5: [reviewed('approve', 'Approved', [], day(5, 9))],
  u1: [reviewed('approve', 'Approved', [], day(2, 11))],
  u7: [reviewed('approve', 'Approved', [], day(3, 9))],
};
// Omar's review was started by Subhash Rai
const underReview = { u9: 'Subhash Rai' };
const queueStatus = p => (underReview[p.id] ? 'under_review' : p.reviewStatus);

const owner = p => ({ id: p.id, email: p.email, accountStatus: p.status || 'active', ...profileOf(p) });

const listing = (id, o, funding, title, desc, amount, category, stage, tech, evidence, extra = {}) => ({
  listing: {
    id, listingType: funding ? 'funding' : 'sale', category: { id: category, name: category }, title, shortDescription: desc,
    techStack: tech, projectStage: stage, askingAmount: amount, currency: 'PKR', coverUrl: null, photos: [], status: 'published',
    isSample: false, reviewStatus: 'pending', reviewNote: null, publishedAt: day(9, 9), createdAt: day(7), updatedAt: day(9, 9),
    owner: { id: o.id, fullName: o.fullName, avatarUrl: null }, ...extra,
  },
  confidential: funding
    ? { fullDescription: 'Soil-moisture sensors report to a phone app over Wi-Fi; the app opens the valve only when the soil is dry. A pilot on two farms near Hyderabad saved about 40% of water.', problemStatement: 'Small farmers over-water because they cannot measure soil moisture.', businessModel: 'One-time kit sale plus a small yearly app subscription.', financialSummary: 'Kit cost PKR 9,000; pilot revenue PKR 120,000; break-even at 400 kits.', ipOwnershipNotes: 'Code and hardware design owned by the founder.', equityOfferedPercent: 10, transferDetails: null }
    : { fullDescription: 'Web and mobile booking system for small clinics with reminders by SMS and patient history.', problemStatement: 'Clinics still book by phone and paper registers.', businessModel: 'One-time sale of the full source code.', financialSummary: 'Hosting costs about PKR 4,000 per month; used by 3 clinics.', ipOwnershipNotes: 'Written entirely by the owner.', equityOfferedPercent: null, transferDetails: 'Full source code, database schema, deployment guide and one month of support.' },
  evidence,
  owner: owner(o),
  reviewStartedBy: extra.reviewStatus === 'under_review' ? 'Subhash Rai' : null,
  decisions: [],
});

const listings = [
  listing('l1', byId('u2'), true, 'Smart irrigation kit', 'Soil sensors and a mobile app that water crops only when they need it.', 1500000, 'AgriTech', 'prototype', ['Flutter', 'ESP32', 'Node.js'], [
    link('p1', 'ownership_proof', 'https://github.com/hamzaali/smart-irrigation', day(8, 18)),
    link('p2', 'project_evidence', 'https://youtu.be/irrigation-pilot-demo', day(8, 18, 5)),
    pdf('p3', 'project_evidence', day(8, 18, 8)),
  ]),
  listing('l2', byId('u7'), false, 'Clinic booking system', 'Appointments, reminders and patient records for small clinics.', 300000, 'HealthTech', 'launched', ['React', 'Express', 'PostgreSQL'], [
    link('p4', 'ownership_proof', 'https://github.com/daniyalakram/clinic-booking', day(8, 12)),
    link('p5', 'project_evidence', 'https://clinicbooking.pk', day(8, 12, 3)),
  ], { reviewStatus: 'under_review' }),
];

const trail = [
  [byId('u4'), 'user', decisionsOf.u4[0]],
  [{ id: 'l9', title: 'Campus wallet' }, 'listing', reviewed('approve', 'Approved', [link('x1', 'ownership_proof', 'https://github.com/x', day(4))], day(5, 16, 40))],
  [byId('u8'), 'user', decisionsOf.u8[0]],
  [byId('u8'), 'user', decisionsOf.u8[1]],
  [{ id: 'l8', title: 'Hostel mess app' }, 'listing', reviewed('request_more', 'Add a demo video as project evidence.', [link('x2', 'ownership_proof', 'https://github.com/y', day(3))], day(4, 11))],
  [byId('u6'), 'user', decisionsOf.u6[0]],
  [byId('u10'), 'user', decisionsOf.u10[0]],
  [byId('u7'), 'user', decisionsOf.u7[0]],
  [byId('u5'), 'user', decisionsOf.u5[0]],
  [byId('u1'), 'user', decisionsOf.u1[0]],
].sort((a, b) => b[2].at.localeCompare(a[2].at)).map(([s, type, d]) => ({
  ...d, reviewerEmail: admin.email,
  subject: type === 'user' ? { type, id: s.id, role: s.role, name: s.fullName, email: s.email } : { type, id: s.id, title: s.title },
}));

const audit = [
  ['admin.user_review_started', 'user', admin, null, day(10, 9, 30)],
  ['verification.expired', 'user', null, null, day(10, 0, 5)],
  ['admin.listing_review_started', 'listing', admin, null, day(9, 17, 2)],
  ['listing.published', 'listing', { email: 'hamza.ali@gmail.com', role: 'owner' }, null, day(9, 9, 5)],
  ['listing.evidence_added', 'listing', { email: 'hamza.ali@gmail.com', role: 'owner' }, { kind: 'ownership_proof', url: 'https://github.com/hamzaali/smart-irrigation' }, day(8, 18, 0)],
  ['profile.document_uploaded', 'user', { email: 'bilal.ahmed@gmail.com', role: 'investor' }, { kind: 'professional_credential' }, day(8, 11, 25)],
  ['profile.document_uploaded', 'user', { email: 'bilal.ahmed@gmail.com', role: 'investor' }, { kind: 'investment_portfolio', url: 'https://angel.co/u/bilal-ahmed' }, day(8, 11, 22)],
  ['profile.updated', 'user', { email: 'bilal.ahmed@gmail.com', role: 'investor' }, null, day(8, 11, 18)],
  ['auth.registered', 'user', { email: 'bilal.ahmed@gmail.com', role: 'investor' }, null, day(8, 11, 2)],
  ['admin.user_suspended', 'user', admin, { reason: 'Fake investment documents' }, day(5, 12, 0)],
  ['admin.user_approved', 'user', admin, { evidenceReviewed: ['company_registration', 'investment_portfolio'] }, day(3, 15, 10)],
  ['auth.login', 'user', admin, null, day(3, 15, 0)],
].map(([action, entityType, actor, details, at], i) => ({
  id: 220 - i, action, entityType, entityId: 'e' + i, details, ip: actor ? '39.40.12.' + (10 + i) : null,
  actor: actor ? { email: actor.email, role: actor.role } : null, at,
}));

const ROLE_GROUPS = { investor: ['investor'], others: ['owner', 'buyer'] };

function route(method, url) {
  const u = new URL(url, 'http://x');
  const p = u.pathname.replace(/^\/api/, '');
  if (method === 'POST' && p === '/auth/login') return { accessToken: 'mock', refreshToken: 'mock', expiresIn: 900, user: admin };
  if (method === 'POST' && (p === '/auth/refresh' || p === '/auth/change-password')) return { accessToken: 'mock', refreshToken: 'mock', expiresIn: 900, user: admin };
  if (method === 'POST' && p === '/auth/logout') return null;
  if (method === 'POST' && p.endsWith('/review/start')) return { started: true };
  if (p === '/admin/stats') return {
    users: {
      owners: 3, investors: 5, buyers: 2, approved: 5, pending: 2, investorsPending: 1, underReview: 1, needsEvidence: 1,
      rejected: 1, expired: 1, notApproved: 3, unverifiedEmail: 1, newToday: 1, locked: 0, suspended: 1, samples: 0,
    },
    listings: { live: 6, pending: 1, underReview: 1, needsChanges: 1, drafts: 3, closed: 1, funding: 7, sale: 5 },
  };
  if (p === '/admin/users') {
    let list = people;
    for (const k of ['role', 'status']) if (u.searchParams.get(k)) list = list.filter(x => (x[k] || 'active') === u.searchParams.get(k));
    if (u.searchParams.get('review')) list = list.filter(x => queueStatus(x) === u.searchParams.get('review'));
    return { users: list.map(x => ({ ...listUser(x), reviewStatus: queueStatus(x) })) };
  }
  if (p.startsWith('/admin/users/')) {
    const person = byId(p.split('/')[3]) || people[0];
    return {
      user: { id: person.id, email: person.email, role: person.role, status: person.status || 'active', emailVerified: true, locked: false, registeredAt: person.at },
      profile: { ...profileOf(person), reviewStatus: queueStatus(person) },
      listings: person.role === 'owner' ? listings.filter(l => l.listing.owner.id === person.id).map(l => l.listing) : [],
      decisions: decisionsOf[person.id] || [],
    };
  }
  if (p === '/admin/reviews/users') {
    const status = u.searchParams.get('status') || 'pending';
    const roles = ROLE_GROUPS[u.searchParams.get('role')] || ['owner', 'investor', 'buyer'];
    return {
      users: people.filter(x => queueStatus(x) === status && roles.includes(x.role)).map(x => ({
        id: x.id, registeredAt: x.at, emailVerified: true, reviewStartedBy: underReview[x.id] || null,
        ...profileOf(x), reviewStatus: queueStatus(x), decisions: decisionsOf[x.id] || [],
      })),
    };
  }
  if (p === '/admin/reviews/listings') {
    const status = u.searchParams.get('status') || 'pending';
    return { listings: listings.filter(l => l.listing.reviewStatus === status) };
  }
  if (p === '/admin/reviews/decisions') {
    const subject = u.searchParams.get('subject');
    return { decisions: subject === 'users' ? trail.filter(d => d.subject.type === 'user') : subject === 'listings' ? trail.filter(d => d.subject.type === 'listing') : trail };
  }
  if (p === '/admin/audit') {
    const group = u.searchParams.get('action');
    return { entries: group ? audit.filter(a => a.action.startsWith(group)) : audit };
  }
  return undefined;
}

http.createServer((req, res) => {
  const cors = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  };
  if (req.method === 'OPTIONS') { res.writeHead(204, cors); return res.end(); }
  req.resume();
  req.on('end', () => {
    const body = route(req.method, req.url);
    if (body === undefined) { res.writeHead(404, { ...cors, 'Content-Type': 'application/json' }); return res.end(JSON.stringify({ error: { code: 'NOT_FOUND', message: 'Not found' } })); }
    if (body === null) { res.writeHead(204, cors); return res.end(); }
    res.writeHead(200, { ...cors, 'Content-Type': 'application/json' });
    res.end(JSON.stringify(body));
  });
}).listen(port, () => console.log('admin mock on ' + port));
