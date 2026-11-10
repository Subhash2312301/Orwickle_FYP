// Request body rules for PUT /api/profile/me, one schema per role. Role-specific fields sit in
// `details`. Documents (owner/buyer ID cards, investor evidence) are uploaded separately
// and checked by the service when the profile is saved. The Flutter form applies the same rules.

const { z } = require('zod');

const required = label => ({ error: `${label} is required` });

const text = (label, max, min = 2) => z.string(required(label))
  .trim()
  .min(min, `${label} must be at least ${min} characters`)
  .max(max, `${label} must be at most ${max} characters`);

const optionalText = (label, max) => z.string()
  .trim()
  .max(max, `${label} must be at most ${max} characters`)
  .nullable()
  .optional()
  .transform(v => v || null);

const URL_PATTERN = /^https?:\/\/[^\s.]+\.[^\s]+$/i;
const urlMessage = label => `Enter a full ${label} starting with https://`;

const optionalUrl = label => z.string()
  .trim()
  .max(300, `${label} is too long`)
  .refine(v => v === '' || URL_PATTERN.test(v), urlMessage(label))
  .nullable()
  .optional()
  .transform(v => v || null);

const requiredUrl = label => z.string(required(label))
  .trim()
  .min(1, `${label} is required`)
  .max(300, `${label} is too long`)
  .refine(v => URL_PATTERN.test(v), urlMessage(label));

const interests = z.array(z.uuid('Invalid category'), required('Interests'))
  .min(1, 'Choose at least one category')
  .max(10, 'Choose at most 10 categories');

// 0300-1234567, 03001234567 or +923001234567 → 03001234567
const phone = z.string(required('Phone number'))
  .transform(v => v.replace(/[\s-]/g, '').replace(/^\+92/, '0'))
  .refine(v => /^03[0-9]{9}$/.test(v), 'Enter a mobile number like 03001234567');

// format only; required for company buyers
const companyEmail = z.string().trim().toLowerCase().max(254)
  .refine(v => v === '' || /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v), 'Enter a valid company email')
  .nullable().optional().transform(v => v || null);

const fullName = text('Full name', 100);
const city = text('City', 80);

// Owners may be university students or independent (self-taught) developers;
// students give university, degree and university ID card, independent owners their CNIC.
// Owners have no city.
const owner = z.object({
  fullName,
  headline: text('Headline', 150),
  bio: text('Bio', 2000, 10),
  linkedinUrl: requiredUrl('LinkedIn profile'),
  websiteUrl: optionalUrl('website URL'),
  details: z.object({
    isStudent: z.boolean({ error: 'Choose whether you are a university student' }),
    university: optionalText('University', 150),
    degreeProgram: optionalText('Degree program', 100),
    skills: z.array(z.string().trim().min(1).max(40, 'Each skill must be at most 40 characters'), required('Skills'))
      .min(1, 'Add at least one skill')
      .max(20, 'Add at most 20 skills')
      .transform(list => [...new Set(list)]),
    githubUrl: requiredUrl('GitHub profile'),
    portfolioUrl: requiredUrl('Portfolio link'),
  }, required('Details')).superRefine((d, ctx) => {
    if (!d.isStudent) return;
    const need = { university: 'University', degreeProgram: 'Degree program' };
    for (const [field, label] of Object.entries(need)) {
      const value = d[field] ?? '';
      if (value.length < 2) ctx.addIssue({ code: 'custom', path: [field], message: `${label} is required for students` });
    }
  }),
});

const PROJECT_STAGES = ['idea', 'prototype', 'mvp', 'launched'];

// Investors are verified by their professional identity and supporting evidence, not by CNIC
// or proof of funds; "interests" are their sector preferences (categories).
const investor = z.object({
  fullName,
  linkedinUrl: requiredUrl('LinkedIn profile'),
  details: z.object({
    organization: text('Organization or company', 150),
    designation: text('Professional designation', 100),
    companyWebsite: optionalUrl('company website'),
    investmentInterests: text('Investment interests', 1000, 10),
    investmentStages: z.array(z.enum(PROJECT_STAGES, { error: 'Invalid stage' }), required('Investment stages'))
      .min(1, 'Choose at least one stage')
      .transform(list => [...new Set(list)]),
    // ranges come from preset chips; a missing maximum means "and above" (1 crore+)
    minTicket: z.number({ error: 'Choose an investment range' }).min(0).max(1e12),
    maxTicket: z.number().min(0).max(1e12).nullable().optional().transform(v => v ?? null),
    interests,
  }, required('Details')).superRefine((d, ctx) => {
    if (d.maxTicket != null && d.maxTicket < d.minTicket) {
      ctx.addIssue({ code: 'custom', path: ['maxTicket'], message: 'Maximum investment must be greater than or equal to the minimum' });
    }
  }),
});

const buyer = z.object({
  fullName,
  city,
  phone,
  linkedinUrl: requiredUrl('LinkedIn profile'),
  details: z.object({
    buyerType: z.enum(['individual', 'small_business', 'agency', 'other'], { error: 'Choose a buyer type' }),
    affiliation: z.enum(['university', 'company'], { error: 'Choose University or Company' }),
    companyName: optionalText('Company name', 150),
    companyEmail,
    interests,
  }, required('Details')).superRefine((d, ctx) => {
    if (d.affiliation !== 'company') return;
    if (!d.companyName) ctx.addIssue({ code: 'custom', path: ['companyName'], message: 'Company name is required' });
    if (!d.companyEmail) ctx.addIssue({ code: 'custom', path: ['companyEmail'], message: 'Company email is required' });
  }),
});

const profileSchemas = { owner, investor, buyer };

// Investor supporting evidence: a file or a link each, at least MIN_INVESTOR_EVIDENCE different kinds.
const INVESTOR_EVIDENCE = [
  'company_registration', 'network_affiliation', 'accelerator_affiliation', 'investment_portfolio', 'professional_credential',
];
const MIN_INVESTOR_EVIDENCE = 2;

// Identity documents owners and buyers must upload before the profile can be submitted for review.
function requiredDocuments(role, details) {
  if (role === 'owner') return details.isStudent ? ['university_id_front', 'university_id_back'] : ['cnic_front', 'cnic_back'];
  if (role === 'buyer') return details.affiliation === 'university' ? ['university_id_front', 'university_id_back'] : [];
  return [];
}

const DOCUMENT_LABELS = {
  cnic_front: 'the front of your CNIC',
  cnic_back: 'the back of your CNIC',
  university_id_front: 'the front of your university ID card',
  university_id_back: 'the back of your university ID card',
  company_registration: 'company registration or business profile',
  network_affiliation: 'VC or angel network affiliation',
  accelerator_affiliation: 'accelerator or incubator affiliation',
  investment_portfolio: 'publicly verifiable investment portfolio',
  professional_credential: 'professional credentials',
};

// Which document kinds each role may upload at all, and which may be given as a link instead of a file.
const ALLOWED_DOCUMENTS = {
  owner: ['university_id_front', 'university_id_back', 'cnic_front', 'cnic_back'],
  investor: INVESTOR_EVIDENCE,
  buyer: ['university_id_front', 'university_id_back'],
};
const LINK_DOCUMENTS = INVESTOR_EVIDENCE;

const evidenceLinkSchema = z.object({ url: requiredUrl('Link') });

module.exports = {
  profileSchemas, requiredDocuments, DOCUMENT_LABELS, ALLOWED_DOCUMENTS, LINK_DOCUMENTS, INVESTOR_EVIDENCE,
  MIN_INVESTOR_EVIDENCE, PROJECT_STAGES, evidenceLinkSchema,
};
