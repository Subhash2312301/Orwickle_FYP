// Reads and saves the logged-in user's profile: common fields + role details + category interests.

const crypto = require('node:crypto');
const { pool, withTransaction } = require('../../db/pool');
const HttpError = require('../../utils/httpError');
const { audit } = require('../../services/audit');
const storage = require('../../services/storage');

const toNumber = v => (v == null ? null : Number(v));

async function loadInterests(db, userId) {
  const { rows } = await db.query(
    `SELECT c.id, c.name FROM user_category_interests i
       JOIN categories c ON c.id = i.category_id
      WHERE i.user_id = $1 ORDER BY c.sort_order, c.name`,
    [userId]);
  return rows;
}

async function getMyProfile(userId, role, { db = pool, baseUrl } = {}) {
  const { rows: [p] } = await db.query(
    `SELECT u.email, p.full_name, p.headline, p.bio, p.city, p.linkedin_url, p.website_url, p.avatar_path,
            p.review_status, p.completed_deal_count, p.profile_completed_at
       FROM users u JOIN profiles p ON p.user_id = u.id WHERE u.id = $1`,
    [userId]);
  if (!p) throw new HttpError(404, 'NOT_FOUND', 'Profile not found');

  const profile = {
    role,
    email: p.email,
    fullName: p.full_name,
    avatarUrl: await storage.signedUrl(p.avatar_path, baseUrl),
    headline: p.headline,
    bio: p.bio,
    city: p.city,
    linkedinUrl: p.linkedin_url,
    websiteUrl: p.website_url,
    reviewStatus: p.review_status,
    completedDealCount: p.completed_deal_count,
    completed: role === 'admin' || Boolean(p.profile_completed_at),
    details: null,
  };

  if (role === 'owner') {
    const { rows: [d] } = await db.query('SELECT * FROM owner_profiles WHERE user_id = $1', [userId]);
    profile.details = d && {
      university: d.university,
      degreeProgram: d.degree_program,
      graduationYear: d.graduation_year,
      skills: d.skills,
      githubUrl: d.github_url,
      portfolioUrl: d.portfolio_url,
    };
  } else if (role === 'investor') {
    const { rows: [d] } = await db.query('SELECT * FROM investor_profiles WHERE user_id = $1', [userId]);
    profile.details = d && {
      investorType: d.investor_type,
      organizationName: d.organization_name,
      minTicket: toNumber(d.min_ticket),
      maxTicket: toNumber(d.max_ticket),
      currency: d.currency,
      interests: await loadInterests(db, userId),
    };
  } else if (role === 'buyer') {
    const { rows: [d] } = await db.query('SELECT * FROM buyer_profiles WHERE user_id = $1', [userId]);
    profile.details = d && {
      buyerType: d.buyer_type,
      companyName: d.company_name,
      companyWebsite: d.company_website,
      budgetMin: toNumber(d.budget_min),
      budgetMax: toNumber(d.budget_max),
      currency: d.currency,
      interests: await loadInterests(db, userId),
    };
  }
  return { profile };
}

async function saveInterests(client, userId, categoryIds) {
  const ids = [...new Set(categoryIds)];
  const { rows } = await client.query(
    'SELECT id FROM categories WHERE id = ANY($1::uuid[]) AND is_active', [ids]);
  if (rows.length !== ids.length) {
    throw new HttpError(400, 'VALIDATION_ERROR', 'Please correct the highlighted fields',
      { 'details.interests': 'One of the chosen categories no longer exists' });
  }
  await client.query('DELETE FROM user_category_interests WHERE user_id = $1', [userId]);
  await client.query(
    `INSERT INTO user_category_interests (user_id, category_id) SELECT $1, unnest($2::uuid[])`,
    [userId, ids]);
}

// Saves the whole profile; the first complete save marks the profile as completed.
async function updateMyProfile(userId, role, body, { ip, baseUrl }) {
  const d = body.details;
  return withTransaction(async client => {
    await client.query(
      `UPDATE profiles
          SET full_name = $2, headline = $3, bio = $4, city = $5, linkedin_url = $6, website_url = $7,
              profile_completed_at = coalesce(profile_completed_at, now())
        WHERE user_id = $1`,
      [userId, body.fullName, body.headline, body.bio, body.city, body.linkedinUrl, body.websiteUrl]);

    if (role === 'owner') {
      await client.query(
        `UPDATE owner_profiles
            SET university = $2, degree_program = $3, graduation_year = $4, skills = $5,
                github_url = $6, portfolio_url = $7
          WHERE user_id = $1`,
        [userId, d.university, d.degreeProgram, d.graduationYear ?? null, d.skills, d.githubUrl, d.portfolioUrl]);
    } else if (role === 'investor') {
      await client.query(
        `UPDATE investor_profiles
            SET investor_type = $2, organization_name = $3, min_ticket = $4, max_ticket = $5, currency = $6
          WHERE user_id = $1`,
        [userId, d.investorType, d.organizationName, d.minTicket, d.maxTicket, d.currency]);
      await saveInterests(client, userId, d.interests);
    } else if (role === 'buyer') {
      await client.query(
        `UPDATE buyer_profiles
            SET buyer_type = $2, company_name = $3, company_website = $4, budget_min = $5, budget_max = $6,
                currency = $7
          WHERE user_id = $1`,
        [userId, d.buyerType, d.companyName, d.companyWebsite, d.budgetMin, d.budgetMax, d.currency]);
      await saveInterests(client, userId, d.interests);
    }

    await audit(client, { actorId: userId, action: 'profile.updated', entityId: userId, ip });
    return getMyProfile(userId, role, { db: client, baseUrl });
  });
}

// Replaces the profile photo; the old file is deleted after the database points to the new one.
async function setAvatar(userId, role, image, { ip, baseUrl }) {
  const filePath = `avatars/${userId}/${crypto.randomUUID()}.${image.ext}`;
  await storage.upload(filePath, image.buffer, image.contentType);
  const { rows: [old] } = await pool.query('SELECT avatar_path FROM profiles WHERE user_id = $1', [userId]);
  await pool.query('UPDATE profiles SET avatar_path = $2 WHERE user_id = $1', [userId, filePath]);
  await storage.remove(old?.avatar_path);
  await audit(pool, { actorId: userId, action: 'profile.avatar_updated', entityId: userId, ip });
  return getMyProfile(userId, role, { baseUrl });
}

async function removeAvatar(userId, role, { ip, baseUrl }) {
  const { rows: [old] } = await pool.query('SELECT avatar_path FROM profiles WHERE user_id = $1', [userId]);
  await pool.query('UPDATE profiles SET avatar_path = NULL WHERE user_id = $1', [userId]);
  await storage.remove(old?.avatar_path);
  await audit(pool, { actorId: userId, action: 'profile.avatar_removed', entityId: userId, ip });
  return getMyProfile(userId, role, { baseUrl });
}

async function listCategories() {
  const { rows } = await pool.query(
    'SELECT id, name, slug FROM categories WHERE is_active ORDER BY sort_order, name');
  return { categories: rows };
}

module.exports = { getMyProfile, updateMyProfile, setAvatar, removeAvatar, listCategories };
