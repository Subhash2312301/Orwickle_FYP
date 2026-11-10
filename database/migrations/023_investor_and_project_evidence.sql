-- =====================================================================
-- Orwickle database — 023: investor verification by evidence, project evidence   (Features 1, 2, 11)
--   investors no longer give a CNIC, proof of funds or investment history. Their profile is:
--     full name, organization, professional designation, LinkedIn, company website,
--     investment interests, investment stages, sector preferences (user_category_interests)
--     and an approximate investment range,
--   backed by at least two pieces of supporting evidence (a file or a link each):
--     company_registration, network_affiliation (VC / angel network), accelerator_affiliation,
--     investment_portfolio, professional_credential.
--   An approved investor shows "Profile Verified" (the evidence was checked; not a guarantee).
--   Listings carry ownership_proof (required to publish) and project_evidence items.
--   review_decisions.evidence_reviewed keeps what the admin had in front of them at decision time.
-- =====================================================================

ALTER TABLE investor_profiles
  ADD COLUMN designation           text CHECK (char_length(designation) <= 100),
  ADD COLUMN investment_interests  text CHECK (char_length(investment_interests) <= 1000),
  ADD COLUMN investment_stages     project_stage[] NOT NULL DEFAULT '{}',
  DROP COLUMN cnic_number,
  DROP COLUMN investor_type,
  DROP COLUMN company_email,
  DROP COLUMN investment_experience,
  DROP COLUMN professional_affiliation,
  DROP COLUMN investment_history,
  DROP COLUMN portfolio_url;

-- investors' phone and city are no longer collected
UPDATE profiles p SET phone = NULL, city = NULL FROM users u WHERE u.id = p.user_id AND u.role = 'investor';

ALTER TABLE evidence_submissions
  DROP CONSTRAINT evidence_kind_check,
  ADD CONSTRAINT evidence_kind_check CHECK (kind IN (
    'cnic_front', 'cnic_back', 'university_id_front', 'university_id_back', 'company_certificate',
    'funds_proof', 'investment_proof',
    'company_registration', 'network_affiliation', 'accelerator_affiliation', 'investment_portfolio',
    'professional_credential',
    'ownership_proof', 'project_evidence',
    'linkedin', 'github_repo', 'other'));

-- which admin opened a submission (status under_review)
ALTER TABLE profiles ADD COLUMN review_started_by uuid REFERENCES users (id);
ALTER TABLE listings ADD COLUMN review_started_by uuid REFERENCES users (id);

ALTER TABLE review_decisions ADD COLUMN evidence_reviewed jsonb NOT NULL DEFAULT '[]';

-- Investors who completed the old profile must fill in the new fields and add evidence.
-- Their CNIC and proof files are deleted by `npm run cleanup:investor-documents` (files live in Storage).
UPDATE profiles p
   SET review_status = 'needs_evidence', reviewed_at = now(),
       review_note = 'Our verification has changed. Please add your designation, investment interests and stages, and at least two pieces of supporting evidence.'
  FROM users u
 WHERE u.id = p.user_id AND u.role = 'investor' AND p.profile_completed_at IS NOT NULL;

CREATE INDEX profiles_needs_evidence_idx ON profiles (reviewed_at) WHERE review_status = 'needs_evidence';
CREATE INDEX listings_needs_evidence_idx ON listings (reviewed_at) WHERE review_status = 'needs_evidence';
