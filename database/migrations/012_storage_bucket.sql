-- =====================================================================
-- Orwickle database — 012: private Supabase Storage bucket
-- Holds pitch documents, evidence files and generated agreement PDFs.
-- Not public: the backend hands out short-lived signed URLs after its permission check.
-- Skipped on plain PostgreSQL (no storage schema).
-- =====================================================================

DO $$
BEGIN
  IF to_regclass('storage.buckets') IS NOT NULL THEN
    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    VALUES ('private-files', 'private-files', false, 10485760,
            ARRAY['application/pdf', 'image/png', 'image/jpeg', 'image/webp'])
    ON CONFLICT (id) DO NOTHING;
  END IF;
END $$;
