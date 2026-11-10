-- =====================================================================
-- Orwickle database — 022: verification statuses   (Feature 11 basics)
--   under_review  an administrator has opened the submission and is checking it
--   expired       more evidence was requested and the user did not answer within 30 days
-- The full set shown to admins: Pending, Under Review, Verified (approved), Rejected,
-- Suspended (users.status) and Expired, plus "more evidence requested" while waiting for the user.
-- New enum values cannot be used in the transaction that adds them, so 023 uses them.
-- =====================================================================

ALTER TYPE review_status ADD VALUE IF NOT EXISTS 'under_review' AFTER 'pending';
ALTER TYPE review_status ADD VALUE IF NOT EXISTS 'expired';
