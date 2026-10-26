-- =====================================================================
-- Orwickle database — 020: buyer company email   (Feature 1)
--   buyers from a company give the company email (format checked, no OTP);
--   buyers' phone and LinkedIn use the existing profiles.phone and profiles.linkedin_url
--   owners no longer give a city; independent owners upload their CNIC (no schema change)
-- =====================================================================

ALTER TABLE buyer_profiles ADD COLUMN company_email text;
