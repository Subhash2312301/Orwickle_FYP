// Request body rules for admin review decisions.

const { z } = require('zod');

const reason = z.string().trim().max(1000, 'Reason must be at most 1000 characters').optional().transform(v => v || null);

// A reason is mandatory whenever the answer is not a plain approval.
const needsReason = d => d.decision === 'approve' || Boolean(d.reason);
const reasonError = { message: 'Give a reason so the user knows what to change', path: ['reason'] };

// What the admin checked, e.g. { "CNIC photo matches name": true, "LinkedIn profile opens": false }.
const checklist = z.record(z.string().max(200), z.boolean()).default({});

const userReviewSchema = z.object({
  decision: z.enum(['approve', 'reject', 'request_more'], { error: 'Choose approve, reject or request more information' }),
  reason,
  checklist,
}).refine(needsReason, reasonError);

const listingReviewSchema = z.object({
  decision: z.enum(['approve', 'reject'], { error: 'Choose approve or reject' }),
  reason,
  checklist,
}).refine(needsReason, reasonError);

// Suspending or reinstating an account always needs a reason (stored and emailed).
const accountStatusSchema = z.object({
  reason: z.string({ error: 'Give a reason' }).trim().min(3, 'Give a reason').max(1000, 'Reason must be at most 1000 characters'),
});

module.exports = { userReviewSchema, listingReviewSchema, accountStatusSchema };
