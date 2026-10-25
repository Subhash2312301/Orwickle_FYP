-- =====================================================================
-- Orwickle database — 019: investor proof documents   (Feature 1 / 11 basics)
--   funds_proof       individual / angel investors: bank statement, bank letter or tax return
--   investment_proof  investors who have invested before: share certificate, investment
--                     agreement or a letter from the startup
--   (investors may also give a personal website: profiles.website_url, no change needed)
-- =====================================================================

ALTER TABLE evidence_submissions
  DROP CONSTRAINT evidence_kind_check,
  ADD CONSTRAINT evidence_kind_check CHECK (kind IN (
    'cnic_front', 'cnic_back', 'university_id_front', 'university_id_back', 'company_certificate',
    'funds_proof', 'investment_proof',
    'linkedin', 'company_registration', 'ownership_proof', 'github_repo', 'other'));
