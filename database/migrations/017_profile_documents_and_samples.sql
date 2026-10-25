-- =====================================================================
-- Orwickle database — 017: verification details, documents and demo data   (Feature 1 / 11 basics)
--   investors: phone, CNIC, company details (firms), investment experience
--   buyers:    university or company affiliation
--   documents (CNIC, university ID, company certificate) live in evidence_submissions,
--   one current file per kind per user
--   is_sample marks demonstration users and listings, shown with a "Sample" badge
-- =====================================================================

ALTER TABLE profiles
  ADD COLUMN phone      text CHECK (phone ~ '^03[0-9]{9}$'),
  ADD COLUMN is_sample  boolean NOT NULL DEFAULT false;

ALTER TABLE investor_profiles
  ADD COLUMN cnic_number            text CHECK (cnic_number ~ '^[0-9]{13}$'),
  ADD COLUMN company_website        text,
  ADD COLUMN company_email          text,
  ADD COLUMN investment_experience  text CHECK (investment_experience IN ('first_time', '1_3', '4_10', '10_plus'));

ALTER TABLE buyer_profiles
  ADD COLUMN affiliation text CHECK (affiliation IN ('university', 'company'));

ALTER TABLE listings ADD COLUMN is_sample boolean NOT NULL DEFAULT false;

ALTER TABLE evidence_submissions
  ADD COLUMN content_type text,
  ADD CONSTRAINT evidence_kind_check CHECK (kind IN (
    'cnic_front', 'cnic_back', 'university_id_front', 'university_id_back', 'company_certificate',
    'linkedin', 'company_registration', 'ownership_proof', 'github_repo', 'other'));

-- one current document of each kind per user (replacing deletes the old row)
CREATE UNIQUE INDEX evidence_one_per_kind_idx
  ON evidence_submissions (subject_user_id, kind) WHERE subject_user_id IS NOT NULL;
