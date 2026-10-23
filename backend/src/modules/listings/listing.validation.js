// Request body rules for creating and editing a listing (Feature 2).
// Public preview fields sit at the top level; confidential fields in `confidential`.
// The Flutter form applies the same rules.

const { z } = require('zod');

const required = label => ({ error: `${label} is required` });

const text = (label, max, min) => z.string(required(label))
  .trim()
  .min(min, `${label} must be at least ${min} characters`)
  .max(max, `${label} must be at most ${max} characters`);

const optionalText = (label, max) => z.string()
  .trim()
  .max(max, `${label} must be at most ${max} characters`)
  .nullable()
  .optional()
  .transform(v => v || null);

const listingSchema = z.object({
  listingType: z.enum(['funding', 'sale'], { error: 'Choose Seeking Funding or Available for Purchase' }),
  categoryId: z.uuid({ error: 'Choose a category' }),
  title: text('Title', 120, 3),
  shortDescription: text('Short description', 500, 10),
  techStack: z.array(z.string().trim().min(1).max(30, 'Each technology must be at most 30 characters'))
    .max(15, 'Add at most 15 technologies')
    .default([])
    .transform(list => [...new Set(list)]),
  projectStage: z.enum(['idea', 'prototype', 'mvp', 'launched'], { error: 'Choose the project stage' }),
  askingAmount: z.number({ error: 'Amount must be a number' })
    .positive('Amount must be greater than 0')
    .max(1e12, 'Amount is too large'),
  currency: z.enum(['PKR', 'USD'], { error: 'Choose PKR or USD' }).default('PKR'),
  confidential: z.object({
    fullDescription: text('Full description', 5000, 20),
    problemStatement: optionalText('Problem statement', 2000),
    solutionDetails: optionalText('Solution details', 3000),
    businessModel: optionalText('Business model', 2000),
    traction: optionalText('Traction', 2000),
    financialSummary: optionalText('Financial summary', 2000),
    roadmap: optionalText('Roadmap', 2000),
    teamDetails: optionalText('Team details', 2000),
    ipOwnershipNotes: optionalText('Ownership notes', 1000),
    equityOfferedPercent: z.number({ error: 'Equity must be a number' })
      .gt(0, 'Equity must be more than 0%')
      .max(100, 'Equity cannot be more than 100%')
      .nullable()
      .optional(),
    transferDetails: optionalText('Transfer details', 2000),
  }, required('Confidential details')),
}).superRefine((d, ctx) => {
  const issue = (field, message) => ctx.addIssue({ code: 'custom', path: ['confidential', field], message });
  if (d.listingType === 'funding' && d.confidential.equityOfferedPercent == null) {
    issue('equityOfferedPercent', 'Equity offered is required for funding listings');
  }
  if (d.listingType === 'sale') {
    if (!d.confidential.transferDetails) issue('transferDetails', 'Describe what the buyer will receive');
    if (d.confidential.equityOfferedPercent != null) issue('equityOfferedPercent', 'Equity applies only to funding listings');
  }
});

module.exports = { listingSchema };
