-- =====================================================================
-- Orwickle database — 013: OTP attempts and session activity   (Feature 1, Phase 2)
-- auth_tokens now also holds:
--   email_verify / password_reset rows = 6-digit OTPs (hash only), max 5 wrong attempts
--   refresh rows = login sessions; rejected after 15 minutes without use (inactivity)
-- =====================================================================

ALTER TABLE auth_tokens
  ADD COLUMN attempts      smallint NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  ADD COLUMN last_used_at  timestamptz,
  ADD COLUMN user_agent    text;

-- finds the current OTP or session of a user quickly
CREATE INDEX auth_tokens_active_idx
  ON auth_tokens (user_id, type, created_at DESC)
  WHERE used_at IS NULL;
