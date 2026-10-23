-- =====================================================================
-- Orwickle database — 015: profile completion   (Feature 1, Phase 2)
-- Set the first time a user saves a complete profile; until then the app
-- sends them to the profile setup screen after login.
-- =====================================================================

ALTER TABLE profiles ADD COLUMN profile_completed_at timestamptz;
