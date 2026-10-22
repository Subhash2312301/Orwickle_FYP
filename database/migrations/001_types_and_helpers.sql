-- =====================================================================
-- Orwickle database — 001: enum types and shared helper functions
-- Target: PostgreSQL 15+ (Supabase)
-- =====================================================================

-- ---------- Enum types ----------
CREATE TYPE user_role              AS ENUM ('owner', 'investor', 'buyer', 'admin');
CREATE TYPE account_status         AS ENUM ('active', 'suspended');
CREATE TYPE auth_token_type        AS ENUM ('refresh', 'email_verify', 'password_reset');
CREATE TYPE review_status          AS ENUM ('unreviewed', 'pending', 'approved', 'rejected', 'needs_evidence');

CREATE TYPE listing_type           AS ENUM ('funding', 'sale');
CREATE TYPE listing_status         AS ENUM ('draft', 'published', 'closed', 'suspended');
CREATE TYPE project_stage          AS ENUM ('idea', 'prototype', 'mvp', 'launched');

CREATE TYPE access_request_status  AS ENUM ('pending', 'approved', 'rejected', 'withdrawn', 'revoked');

CREATE TYPE offer_status           AS ENUM ('open', 'accepted', 'rejected', 'expired', 'withdrawn');
CREATE TYPE offer_version_status   AS ENUM ('pending', 'countered', 'accepted', 'rejected', 'expired', 'withdrawn');

CREATE TYPE document_kind          AS ENUM ('pitch_deck', 'project_report', 'screenshot', 'other');

CREATE TYPE agreement_status       AS ENUM ('draft', 'acknowledged', 'cancelled');
CREATE TYPE revision_status        AS ENUM ('open', 'addressed', 'declined');

CREATE TYPE report_reason          AS ENUM ('spam', 'fraud', 'misleading', 'inappropriate', 'other');
CREATE TYPE report_status          AS ENUM ('open', 'reviewing', 'resolved', 'dismissed');

CREATE TYPE evidence_status        AS ENUM ('pending', 'approved', 'rejected', 'more_requested');
CREATE TYPE review_decision_type   AS ENUM ('approve', 'reject', 'request_more', 'suspend', 'reinstate');

-- ---------- Helper trigger functions ----------

-- Keeps updated_at current on every UPDATE.
CREATE FUNCTION set_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$;

-- Blocks UPDATE/DELETE on append-only tables (versions, acknowledgements, audit).
CREATE FUNCTION prevent_changes() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION '% is append-only: % is not allowed', TG_TABLE_NAME, TG_OP
    USING ERRCODE = 'restrict_violation';
END $$;
