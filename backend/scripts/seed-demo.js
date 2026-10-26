// Demo data for presentations: approved sample users and listings, all flagged is_sample
// (the app shows a "Sample" badge) with emails at @demo.orwickle.app.
// Usage: npm run seed:demo             create (or re-create) the demo data
//        npm run seed:demo -- --remove  delete all of it; real users are never touched

const bcrypt = require('bcryptjs');
const { pool, withTransaction } = require('../src/db/pool');
const authConfig = require('../src/config/auth');

const DOMAIN = '@demo.orwickle.app';
const PASSWORD = 'Demo#Orwickle26';

const owners = [
  { key: 'ayesha', name: 'Ayesha Khan', headline: 'Final-year CS student building EdTech apps', student: true, university: 'SZABIST Karachi', degree: 'BS Computer Science', skills: ['Flutter', 'Node.js', 'PostgreSQL'] },
  // self-taught developer, not at a university
  { key: 'hamza', name: 'Hamza Siddiqui', headline: 'Self-taught developer shipping small business tools', student: false, skills: ['React', 'Express', 'UI/UX'] },
];
const investors = [
  { key: 'farhan', name: 'Farhan Malik', type: 'angel', experience: '4_10', min: 500000, max: 2000000, cats: ['edtech', 'fintech', 'healthtech'] },
  { key: 'sana', name: 'Sana Iqbal', type: 'firm', experience: '10_plus', min: 2000000, max: 10000000, cats: ['agritech', 'saas', 'fintech'], company: 'Karachi Seed Ventures' },
];
const buyers = [
  { key: 'imran', name: 'Imran Sheikh', type: 'small_business', affiliation: 'company', company: 'Sheikh Traders', cats: ['saas', 'e-commerce'] },
  { key: 'zainab', name: 'Zainab Ali', type: 'individual', affiliation: 'university', cats: ['mobile-app', 'web-app'] },
];

const listings = [
  { owner: 'ayesha', type: 'funding', cat: 'edtech', stage: 'mvp', amount: 1500000, equity: 10, title: 'StudyBuddy — AI practice for O Levels', short: 'Students practise past papers and get instant marking with weak-topic reports.', tech: ['Flutter', 'Node.js'] },
  { owner: 'ayesha', type: 'funding', cat: 'healthtech', stage: 'prototype', amount: 800000, equity: 8, title: 'MedQueue — clinic token system', short: 'Patients book a token from home and see live queue position for small clinics.', tech: ['Flutter', 'PostgreSQL'] },
  { owner: 'hamza', type: 'funding', cat: 'agritech', stage: 'idea', amount: 3000000, equity: 15, title: 'KisanConnect — farmer to buyer marketplace', short: 'Connects farmers in Sindh directly with wholesale buyers to cut middlemen costs.', tech: ['React', 'Node.js'] },
  { owner: 'hamza', type: 'sale', cat: 'saas', stage: 'launched', amount: 250000, title: 'ShopKhata — inventory and udhaar app', short: 'Track stock, daily sales and customer credit for kiryana stores, works offline.', tech: ['Flutter', 'SQLite'] },
  { owner: 'ayesha', type: 'sale', cat: 'mobile-app', stage: 'launched', amount: 180000, title: 'CampusRide — student ride sharing', short: 'Students share rides to campus and split fuel costs, with university email login.', tech: ['Flutter', 'Node.js'] },
  { owner: 'hamza', type: 'sale', cat: 'web-app', stage: 'mvp', amount: 120000, title: 'EventHub — society event manager', short: 'University societies publish events, sell passes and check in guests with QR codes.', tech: ['React', 'Express'] },
];

const email = key => `${key}${DOMAIN}`;

async function remove(client) {
  const users = `SELECT id FROM users WHERE email LIKE $1`;
  const ls = `SELECT l.id FROM listings l JOIN users u ON u.id = l.owner_id WHERE u.email LIKE $1`;
  const like = [`%${DOMAIN}`];
  await client.query('ALTER TABLE audit_logs DISABLE TRIGGER audit_logs_immutable');
  await client.query('ALTER TABLE review_decisions DISABLE TRIGGER review_decisions_immutable');
  await client.query(`DELETE FROM audit_logs WHERE entity_id IN (${users}) OR entity_id IN (${ls}) OR actor_id IN (${users})`, like);
  await client.query(`DELETE FROM review_decisions WHERE subject_user_id IN (${users}) OR subject_listing_id IN (${ls})`, like);
  await client.query('ALTER TABLE review_decisions ENABLE TRIGGER review_decisions_immutable');
  await client.query('ALTER TABLE audit_logs ENABLE TRIGGER audit_logs_immutable');
  await client.query(
    `DELETE FROM evidence_submissions WHERE submitted_by IN (${users}) OR subject_user_id IN (${users}) OR subject_listing_id IN (${ls})`,
    like);
  const { rowCount: removedListings } = await client.query(`DELETE FROM listings WHERE id IN (${ls})`, like);
  const { rowCount: removedUsers } = await client.query(`DELETE FROM users WHERE id IN (${users})`, like);
  return { removedUsers, removedListings };
}

async function createUser(client, key, role, name, hash) {
  const { rows: [u] } = await client.query(
    `INSERT INTO users (email, password_hash, role, email_verified_at, terms_accepted_at)
     VALUES ($1, $2, $3, now(), now()) RETURNING id`, [email(key), hash, role]);
  await client.query(
    `INSERT INTO profiles (user_id, full_name, city, review_status, reviewed_at, profile_completed_at, is_sample)
     VALUES ($1, $2, 'Karachi', 'approved', now(), now(), true)`, [u.id, name]);
  return u.id;
}

async function main() {
  const removing = process.argv.includes('--remove');
  const hash = removing ? null : await bcrypt.hash(PASSWORD, authConfig.bcryptRounds);

  await withTransaction(async client => {
    const removed = await remove(client);
    if (removing) {
      console.log(`Removed ${removed.removedUsers} sample users and ${removed.removedListings} sample listings.`);
      return;
    }

    const { rows: cats } = await client.query('SELECT id, slug FROM categories');
    const cat = Object.fromEntries(cats.map(c => [c.slug, c.id]));
    const ids = {};

    for (const o of owners) {
      ids[o.key] = await createUser(client, o.key, 'owner', o.name, hash);
      await client.query('UPDATE profiles SET headline = $2, bio = $3, linkedin_url = $4, city = NULL WHERE user_id = $1',
        [ids[o.key], o.headline, `Sample bio for demonstration. ${o.headline}.`, `https://www.linkedin.com/in/sample-${o.key}`]);
      await client.query(
        `INSERT INTO owner_profiles (user_id, is_student, university, degree_program, skills, github_url, portfolio_url)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [ids[o.key], o.student, o.university ?? null, o.degree ?? null, o.skills,
          `https://github.com/sample-${o.key}`, `https://sample-${o.key}.example.com`]);
    }
    for (const i of investors) {
      const id = await createUser(client, i.key, 'investor', i.name, hash);
      await client.query(
        `UPDATE profiles SET phone = '03001234567', linkedin_url = $2 WHERE user_id = $1`,
        [id, `https://www.linkedin.com/in/sample-${i.key}`]);
      await client.query(
        `INSERT INTO investor_profiles (user_id, investor_type, cnic_number, organization_name, company_website, company_email,
                                        investment_experience, min_ticket, max_ticket)
         VALUES ($1, $2, '4210100000000', $3, $4, $5, $6, $7, $8)`,
        [id, i.type, i.company ?? null, i.company ? 'https://example.com' : null,
          i.company ? `invest${DOMAIN}` : null, i.experience, i.min, i.max]);
      for (const c of i.cats) await client.query('INSERT INTO user_category_interests VALUES ($1, $2)', [id, cat[c]]);
    }
    for (const b of buyers) {
      const id = await createUser(client, b.key, 'buyer', b.name, hash);
      await client.query(
        `UPDATE profiles SET phone = '03001234567', linkedin_url = $2 WHERE user_id = $1`,
        [id, `https://www.linkedin.com/in/sample-${b.key}`]);
      await client.query(
        `INSERT INTO buyer_profiles (user_id, buyer_type, affiliation, company_name, company_email) VALUES ($1, $2, $3, $4, $5)`,
        [id, b.type, b.affiliation, b.company ?? null, b.company ? `buy${DOMAIN}` : null]);
      for (const c of b.cats) await client.query('INSERT INTO user_category_interests VALUES ($1, $2)', [id, cat[c]]);
    }

    for (const l of listings) {
      const { rows: [listing] } = await client.query(
        `INSERT INTO listings (owner_id, listing_type, category_id, title, short_description, tech_stack, project_stage,
                               asking_amount, status, review_status, published_at, reviewed_at, is_sample)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'published', 'approved', now(), now(), true) RETURNING id`,
        [ids[l.owner], l.type, cat[l.cat], l.title, l.short, l.tech, l.stage, l.amount]);
      await client.query(
        `INSERT INTO listing_confidential (listing_id, full_description, problem_statement, business_model,
           financial_summary, ip_ownership_notes, equity_offered_percent, transfer_details)
         VALUES ($1, $2, 'Sample problem statement for demonstration.', 'Sample business model for demonstration.',
           'Sample financial summary for demonstration.', 'All code is written and owned by the project owner.', $3, $4)`,
        [listing.id, `Sample listing for demonstration. ${l.short} Full details are shared with approved requesters.`,
          l.type === 'funding' ? l.equity : null,
          l.type === 'sale' ? 'Full source code, database schema, deployment guide and one month of support.' : null]);
    }
  });

  if (!removing) {
    console.log(`Created ${owners.length + investors.length + buyers.length} sample users and ${listings.length} sample listings.`);
    console.log(`Log in as e.g. ayesha${DOMAIN} (owner), farhan${DOMAIN} (investor), imran${DOMAIN} (buyer)`);
    console.log(`Password for all sample accounts: ${PASSWORD}`);
  }
}

main()
  .catch(err => {
    console.error(err.message);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
