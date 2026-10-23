-- =====================================================================
-- Orwickle database — 014: account lockout and terms acceptance   (Feature 1, Phase 2)
--   5 wrong passwords in a row lock the account for 15 minutes
--   (the per-IP rate limit alone cannot stop guessing from many IPs)
--   terms_accepted_at records when the user accepted the terms and disclaimer
-- =====================================================================

ALTER TABLE users
  ADD COLUMN failed_login_count  smallint NOT NULL DEFAULT 0 CHECK (failed_login_count >= 0),
  ADD COLUMN locked_until        timestamptz,
  ADD COLUMN terms_accepted_at   timestamptz;
