// Request body rules for admin review decisions.

const { z } = require('zod');

const reason = z.string().trim().max(1000, 'Reason must be at most 1000 characters').optional().transform(v => v || null);

// A reason is mandatory whenever the answer is not a plain approval.
const needsReason = d => d.decision === 'approve' || Boolean(d.reason);
const reasonError = { message: 'Give a reason so the user knows what to change', path: ['reason'] };

const userReviewSchema = z.object({
  decision: z.enum(['approve', 'reject', 'request_more'], { error: 'Choose approve, reject or request more information' }),
  reason,
}).refine(needsReason, reasonError);

const listingReviewSchema = z.object({
  decision: z.enum(['approve', 'reject'], { error: 'Choose approve or reject' }),
  reason,
}).refine(needsReason, reasonError);

module.exports = { userReviewSchema, listingReviewSchema };
