-- =====================================================================
-- Orwickle database — 011: lock down Supabase's auto-generated API
-- The Node.js backend connects as the database owner and bypasses RLS.
-- Enabling RLS with no policies means the public anon/authenticated keys
-- can read or write nothing, even if a key leaks from a client.
-- =====================================================================

DO $$
DECLARE
  t text;
BEGIN
  FOR t IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
  END LOOP;

  -- Supabase-only roles; skipped on a plain PostgreSQL install
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM anon, authenticated;
    REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
    REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon, authenticated;
  END IF;
END $$;
