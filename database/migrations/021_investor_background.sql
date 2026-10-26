-- =====================================================================
-- Orwickle database — 021: investor background   (Feature 1)
--   professional_affiliation  employer, association or network (all investors)
--   investment_history        past investments (investors who have invested before)
--   portfolio_url             link to an investment portfolio, e.g. AngelList or a website (optional)
-- =====================================================================

ALTER TABLE investor_profiles
  ADD COLUMN professional_affiliation  text,
  ADD COLUMN investment_history        text,
  ADD COLUMN portfolio_url             text;
