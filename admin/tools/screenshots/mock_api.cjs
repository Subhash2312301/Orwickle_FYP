// Mock of the Orwickle admin API (same response shapes as backend/src/modules/admin), for screenshots only.
// node tools/screenshots/mock_api.js 4100
const http = require('http');

const port = Number(process.argv[2] || 4100);
const day = (n, h = 10, m = 0) => new Date(Date.UTC(2026, 9, n, h - 5, m)).toISOString(); // Oct 2026, PKT

const admin = { id: 'a0000000-0000-4000-8000-000000000001', email: 'subhash@gmail.com', role: 'admin', fullName: 'Subhash Rai', emailVerified: true, profileCompleted: true, approvalStatus: 'approved' };

const people = [
  { id: 'u1', role: 'owner', fullName: 'Ayesha Khan', email: 'ayesha.khan@gmail.com', reviewStatus: 'approved', at: day(12) },
  { id: 'u2', role: 'owner', fullName: 'Hamza Ali', email: 'hamza.ali@gmail.com', reviewStatus: 'pending', at: day(29, 14) },
  { id: 'u3', role: 'investor', fullName: 'Bilal Ahmed', email: 'bilal.ahmed@gmail.com', reviewStatus: 'pending', at: day(30, 11) },
  { id: 'u4', role: 'investor', fullName: 'Fatima Noor', email: 'fatima.noor@gmail.com', reviewStatus: 'approved', at: day(18) },
  { id: 'u5', role: 'buyer', fullName: 'Usman Tariq', email: 'usman.tariq@gmail.com', reviewStatus: 'approved', at: day(20) },
  { id: 'u6', role: 'buyer', fullName: 'Zainab Hussain', email: 'zainab.hussain@gmail.com', reviewStatus: 'needs_evidence', at: day(26) },
  { id: 'u7', role: 'owner', fullName: 'Daniyal Akram', email: 'daniyal.akram@gmail.com', reviewStatus: 'approved', at: day(15) },
  { id: 'u8', role: 'investor', fullName: 'Maryam Shah', email: 'maryam.shah@gmail.com', reviewStatus: 'rejected', at: day(22), status: 'suspended' },
];

const listUser = p => ({
  id: p.id, email: p.email, role: p.role, fullName: p.fullName, status: p.status || 'active', reviewStatus: p.reviewStatus,
  emailVerified: true, locked: false, isSample: false, registeredAt: p.at,
});

const ownerDetails = {
  isStudent: true, university: 'SZABIST Karachi', degreeProgram: 'BS Computer Science',
  skills: ['Flutter', 'Node.js', 'PostgreSQL', 'IoT'], githubUrl: 'https://github.com/hamzaali', portfolioUrl: 'https://hamzaali.dev',
};

const profileOf = p => {
  const base = {
    role: p.role, email: p.email, fullName: p.fullName, avatarUrl: null, phone: '03001234567',
    reviewStatus: p.reviewStatus, reviewNote: p.reviewStatus === 'needs_evidence' ? 'Please upload a clearer photo of your university ID.' : null,
    completedDealCount: 0, completed: true, isSample: false, documents: [],
  };
  if (p.role === 'owner') {
    return { ...base, headline: 'CS student building AgriTech hardware', bio: 'Final-year student at SZABIST. I build low-cost IoT devices and the apps that run them.', city: 'Karachi', linkedinUrl: 'https://www.linkedin.com/in/hamza-ali', websiteUrl: null, details: ownerDetails };
  }
  if (p.role === 'investor') {
    return { ...base, headline: null, bio: null, city: 'Lahore', linkedinUrl: 'https://www.linkedin.com/in/bilal-ahmed', websiteUrl: null, details: {
      investorType: 'angel', cnicNumber: '3520212345671', companyName: null, companyWebsite: null, companyEmail: null,
      investmentExperience: '1_3', professionalAffiliation: 'Product manager at a Lahore fintech; member of an angel network',
      investmentHistory: 'Invested in two student startups in 2025 (EdTech and logistics).', portfolioUrl: null,
      minTicket: 500000, maxTicket: 2000000, interests: [{ id: 'c1', name: 'AgriTech' }, { id: 'c2', name: 'EdTech' }, { id: 'c3', name: 'FinTech' }],
    } };
  }
  return { ...base, headline: null, bio: null, city: 'Islamabad', linkedinUrl: 'https://www.linkedin.com/in/zainab-hussain', websiteUrl: null, details: {
    buyerType: 'small_business', affiliation: 'university', companyName: null, companyEmail: null,
    interests: [{ id: 'c4', name: 'HealthTech' }, { id: 'c5', name: 'E-commerce' }],
  } };
};

const listing = (id, owner, funding, title, desc, amount, category, stage, status, review, tech) => ({
  listing: {
    id, listingType: funding ? 'funding' : 'sale', category: { id: category, name: category }, title, shortDescription: desc,
    techStack: tech, projectStage: stage, askingAmount: amount, currency: 'PKR', coverUrl: null, photos: [], status,
    isSample: false, reviewStatus: review, reviewNote: null, publishedAt: day(30, 9), createdAt: day(27), updatedAt: day(30, 9),
    owner: { id: owner.id, fullName: owner.fullName, avatarUrl: null },
  },
  confidential: funding
    ? { fullDescription: 'Soil-moisture sensors report to a phone app over Wi-Fi; the app opens the valve only when the soil is dry. A pilot on two farms near Hyderabad saved about 40% of water.', problemStatement: 'Small farmers over-water because they cannot measure soil moisture.', businessModel: 'One-time kit sale plus a small yearly app subscription.', financialSummary: 'Kit cost PKR 9,000; pilot revenue PKR 120,000; break-even at 400 kits.', ipOwnershipNotes: 'Code and hardware design owned by the founder.', equityOfferedPercent: 10, transferDetails: null }
    : { fullDescription: 'Web and mobile booking system for small clinics with reminders by SMS and patient history.', problemStatement: 'Clinics still book by phone and paper registers.', businessModel: 'One-time sale of the full source code.', financialSummary: 'Hosting costs about PKR 4,000 per month.', ipOwnershipNotes: 'Written entirely by the owner.', equityOfferedPercent: null, transferDetails: 'Full source code, database schema, deployment guide and one month of support.' },
});

const [hamza, , , , , , daniyal] = people;
const pendingListings = [
  listing('l1', hamza, true, 'Smart irrigation kit', 'Soil sensors and a mobile app that water crops only when they need it.', 1500000, 'AgriTech', 'prototype', 'published', 'pending', ['Flutter', 'ESP32', 'Node.js']),
  listing('l2', daniyal, false, 'Clinic booking system', 'Appointments, reminders and patient records for small clinics.', 300000, 'HealthTech', 'launched', 'published', 'pending', ['React', 'Express', 'PostgreSQL']),
];

const audit = [
  ['admin.listing_approved', 'listing', admin, { title: 'Campus wallet' }, day(31, 16, 40)],
  ['admin.user_approved', 'user', admin, { email: 'fatima.noor@gmail.com' }, day(31, 16, 22)],
  ['auth.login', 'user', admin, null, day(31, 16, 15)],
  ['listing.published', 'listing', { email: 'hamza.ali@gmail.com', role: 'owner' }, { title: 'Smart irrigation kit' }, day(30, 9, 5)],
  ['listing.created', 'listing', { email: 'hamza.ali@gmail.com', role: 'owner' }, { title: 'Smart irrigation kit' }, day(29, 18, 30)],
  ['profile.document_uploaded', 'profile', { email: 'bilal.ahmed@gmail.com', role: 'investor' }, { kind: 'cnic_front' }, day(30, 11, 20)],
  ['profile.updated', 'profile', { email: 'bilal.ahmed@gmail.com', role: 'investor' }, null, day(30, 11, 18)],
  ['auth.email_verified', 'user', { email: 'bilal.ahmed@gmail.com', role: 'investor' }, null, day(30, 11, 4)],
  ['auth.registered', 'user', { email: 'bilal.ahmed@gmail.com', role: 'investor' }, null, day(30, 11, 2)],
  ['auth.login_failed', 'user', { email: 'usman.tariq@gmail.com', role: 'buyer' }, { remainingAttempts: 4 }, day(28, 21, 10)],
  ['admin.user_suspended', 'user', admin, { reason: 'Fake investment documents' }, day(27, 12, 0)],
  ['admin.created', 'user', admin, null, day(10, 9, 0)],
].map(([action, entityType, actor, details, at], i) => ({
  id: 120 - i, action, entityType, entityId: 'e' + i, details, ip: '39.40.12.' + (10 + i),
  actor: actor ? { email: actor.email, role: actor.role } : null, at,
}));

function route(method, url) {
  const u = new URL(url, 'http://x');
  const p = u.pathname.replace(/^\/api/, '');
  if (method === 'POST' && p === '/auth/login') return { accessToken: 'mock', refreshToken: 'mock', expiresIn: 900, user: admin };
  if (method === 'POST' && (p === '/auth/refresh' || p === '/auth/change-password')) return { accessToken: 'mock', refreshToken: 'mock', expiresIn: 900, user: admin };
  if (method === 'POST' && p === '/auth/logout') return null;
  if (p === '/admin/stats') return {
    users: { owners: 3, investors: 3, buyers: 2, approved: 4, pending: 2, notApproved: 2, unverifiedEmail: 1, newToday: 1, locked: 0, suspended: 1, samples: 0 },
    listings: { live: 6, pending: 2, drafts: 3, closed: 1, funding: 7, sale: 5 },
  };
  if (p === '/admin/users') {
    let list = people;
    for (const k of ['role', 'status']) if (u.searchParams.get(k)) list = list.filter(x => (x[k] || 'active') === u.searchParams.get(k));
    if (u.searchParams.get('review')) list = list.filter(x => x.reviewStatus === u.searchParams.get('review'));
    return { users: list.map(listUser) };
  }
  if (p.startsWith('/admin/users/')) {
    const person = people.find(x => x.id === p.split('/')[3]) || hamza;
    return {
      user: { id: person.id, email: person.email, role: person.role, status: person.status || 'active', emailVerified: true, locked: false, registeredAt: person.at },
      profile: profileOf(person),
      listings: person.role === 'owner' ? pendingListings.filter(l => l.listing.owner.id === person.id).map(l => l.listing) : [],
      decisions: person.reviewStatus === 'pending' ? [] : [{ decision: 'approve', reason: null, checklist: {}, reviewer: 'Subhash Rai', at: day(25, 15) }],
    };
  }
  if (p === '/admin/reviews/users') {
    const status = u.searchParams.get('status') || 'pending';
    return { users: people.filter(x => x.reviewStatus === status).map(x => ({ id: x.id, registeredAt: x.at, ...profileOf(x) })) };
  }
  if (p === '/admin/reviews/listings') {
    const status = u.searchParams.get('status') || 'pending';
    return { listings: status === 'pending' ? pendingListings : [] };
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
