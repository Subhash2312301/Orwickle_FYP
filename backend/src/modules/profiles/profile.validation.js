// Request body rules for PUT /api/profile/me. The common fields apply to every role;
// the `details` object depends on the user's role. The Flutter form applies the same rules.

const { z } = require('zod');

const required = label => ({ error: `${label} is required` });

const text = (label, max, min = 1) => z.string(required(label))
  .trim()
  .min(min, min === 1 ? `${label} is required` : `${label} must be at least ${min} characters`)
  .max(max, `${label} must be at most ${max} characters`);

const optionalText = (label, max) => z.string()
  .trim()
  .max(max, `${label} must be at most ${max} characters`)
  .optional()
  .transform(v => v || null);

const optionalUrl = label => z.string()
  .trim()
  .max(300, `${label} is too long`)
  .refine(v => v === '' || /^https?:\/\/[^\s.]+\.[^\s]+$/i.test(v), `Enter a full ${label} starting with https://`)
  .optional()
  .transform(v => v || null);

const amount = label => z.number({ error: `${label} must be a number` })
  .min(0, `${label} cannot be negative`)
  .max(1e12, `${label} is too large`);

const currency = z.enum(['PKR', 'USD'], { error: 'Choose PKR or USD' }).default('PKR');

const interests = z.array(z.uuid('Invalid category'), required('Interests'))
  .min(1, 'Choose at least one category')
  .max(10, 'Choose at most 10 categories');

// max must not be below min
const rangeOk = (minKey, maxKey, label) => [
  d => d[minKey] == null || d[maxKey] == null || d[maxKey] >= d[minKey],
  { message: `Maximum ${label} must be greater than or equal to the minimum`, path: [maxKey] },
];

const common = {
  fullName: text('Full name', 100, 2),
  headline: text('Headline', 150, 2),
  city: text('City', 80, 2),
  bio: optionalText('Bio', 2000),
  linkedinUrl: optionalUrl('LinkedIn URL'),
  websiteUrl: optionalUrl('website URL'),
};

const ownerDetails = z.object({
  university: text('University', 150, 2),
  degreeProgram: text('Degree program', 100, 2),
  graduationYear: z.number({ error: 'Graduation year must be a number' }).int()
    .min(1990, 'Enter a valid graduation year').max(2100, 'Enter a valid graduation year')
    .nullable().optional(),
  skills: z.array(z.string().trim().min(1).max(40, 'Each skill must be at most 40 characters'), required('Skills'))
    .min(1, 'Add at least one skill')
    .max(20, 'Add at most 20 skills')
    .transform(list => [...new Set(list)]),
  githubUrl: optionalUrl('GitHub URL'),
  portfolioUrl: optionalUrl('portfolio URL'),
});

const investorDetails = z.object({
  investorType: z.enum(['individual', 'angel', 'firm', 'other'], { error: 'Choose an investor type' }),
  organizationName: optionalText('Organization name', 150),
  minTicket: amount('Minimum investment'),
  maxTicket: amount('Maximum investment'),
  currency,
  interests,
}).refine(...rangeOk('minTicket', 'maxTicket', 'investment'));

const buyerDetails = z.object({
  buyerType: z.enum(['individual', 'small_business', 'agency', 'other'], { error: 'Choose a buyer type' }),
  companyName: optionalText('Company name', 150),
  companyWebsite: optionalUrl('company website'),
  budgetMin: amount('Minimum budget'),
  budgetMax: amount('Maximum budget'),
  currency,
  interests,
}).refine(...rangeOk('budgetMin', 'budgetMax', 'budget'));

const profileSchemas = {
  owner: z.object({ ...common, details: ownerDetails }),
  investor: z.object({ ...common, details: investorDetails }),
  buyer: z.object({ ...common, details: buyerDetails }),
};

module.exports = { profileSchemas };
