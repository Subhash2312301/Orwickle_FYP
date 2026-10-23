-- =====================================================================
-- Orwickle database — 016: admin approval of accounts and listings   (Feature 11 basics)
-- Every non-admin account is reviewed by an administrator:
--   profiles.review_status  unreviewed → pending (profile submitted) → approved / rejected / needs_evidence
-- Listings are reviewed after publishing and shown to others only once approved.
-- review_note keeps the latest reason shown to the user; the full history stays in review_decisions.
-- =====================================================================

ALTER TABLE profiles ADD COLUMN review_note text;
ALTER TABLE listings ADD COLUMN review_note text;

-- admins are trusted from the start
UPDATE profiles p SET review_status = 'approved', reviewed_at = coalesce(reviewed_at, now())
  FROM users u
 WHERE u.id = p.user_id AND u.role = 'admin';

-- profiles already completed before this change wait for review
UPDATE profiles SET review_status = 'pending'
 WHERE profile_completed_at IS NOT NULL AND review_status = 'unreviewed';

CREATE INDEX profiles_review_queue_idx ON profiles (review_status) WHERE review_status = 'pending';
