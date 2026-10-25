-- =====================================================================
-- Orwickle database — 018: owner type, simpler confidential details, listing photos   (Features 1, 2)
--   owners can be university students or independent (self-taught) developers;
--   university, degree and the university ID card are asked only from students
--   graduation year, solution details, traction, roadmap and team are no longer collected
--   listing_photos holds extra project photos (hardware, screenshots) shown with the preview
-- =====================================================================

ALTER TABLE owner_profiles
  ADD COLUMN is_student boolean NOT NULL DEFAULT true,
  DROP COLUMN graduation_year;

ALTER TABLE listing_confidential
  DROP COLUMN solution_details,
  DROP COLUMN traction,
  DROP COLUMN roadmap,
  DROP COLUMN team_details;

CREATE TABLE listing_photos (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id  uuid NOT NULL REFERENCES listings (id) ON DELETE CASCADE,
  path        text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX listing_photos_listing_idx ON listing_photos (listing_id, created_at);

-- same rule as every other table: only the backend (service role) reads and writes
ALTER TABLE listing_photos ENABLE ROW LEVEL SECURITY;
