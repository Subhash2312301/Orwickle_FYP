-- =====================================================================
-- Orwickle database — 008: draft agreement management   (Feature 9)
-- An accepted offer version produces a draft term sheet. Each change is a new,
-- immutable version, and acknowledgements are tied to one exact version.
-- Draft records only — not a legally enforceable contract.
-- =====================================================================

CREATE TABLE agreements (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  offer_id                 uuid NOT NULL UNIQUE,
  source_offer_version_id  uuid NOT NULL,
  listing_id               uuid NOT NULL REFERENCES listings (id),
  owner_id                 uuid NOT NULL REFERENCES users (id),
  counterparty_id          uuid NOT NULL REFERENCES users (id),
  status                   agreement_status NOT NULL DEFAULT 'draft',
  current_version_no       integer NOT NULL DEFAULT 0,
  cancelled_at             timestamptz,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (source_offer_version_id, offer_id) REFERENCES offer_versions (id, offer_id),
  CONSTRAINT agreements_cancelled CHECK (status <> 'cancelled' OR cancelled_at IS NOT NULL),
  CONSTRAINT agreements_id_parties_key UNIQUE (id, owner_id, counterparty_id)
);
CREATE INDEX agreements_owner_idx        ON agreements (owner_id);
CREATE INDEX agreements_counterparty_idx ON agreements (counterparty_id);

CREATE TRIGGER agreements_updated_at BEFORE UPDATE ON agreements
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE agreement_versions (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agreement_id      uuid NOT NULL REFERENCES agreements (id),
  version_no        integer NOT NULL CHECK (version_no > 0),   -- assigned by trigger
  terms             jsonb NOT NULL,           -- snapshot of the terms rendered in the PDF
  pdf_storage_path  text NOT NULL,            -- generated term sheet in the private bucket
  content_hash      text NOT NULL,            -- SHA-256 of the PDF, proves it was not altered
  change_summary    text,
  created_by        uuid NOT NULL REFERENCES users (id),
  created_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT agreement_versions_no_key UNIQUE (agreement_id, version_no),
  CONSTRAINT agreement_versions_id_agreement_key UNIQUE (id, agreement_id)
);

-- Assign the next version_no and keep agreements.current_version_no in step.
-- A new version resets the agreement to 'draft' so both parties must acknowledge again.
CREATE FUNCTION agreement_versions_before_insert() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  a agreements%ROWTYPE;
BEGIN
  SELECT * INTO a FROM agreements WHERE id = NEW.agreement_id FOR UPDATE;
  IF a.status = 'cancelled' THEN
    RAISE EXCEPTION 'agreement % is cancelled', a.id USING ERRCODE = 'check_violation';
  END IF;
  NEW.version_no := a.current_version_no + 1;
  UPDATE agreements SET current_version_no = NEW.version_no, status = 'draft' WHERE id = a.id;
  RETURN NEW;
END $$;

CREATE TRIGGER agreement_versions_insert BEFORE INSERT ON agreement_versions
  FOR EACH ROW EXECUTE FUNCTION agreement_versions_before_insert();
CREATE TRIGGER agreement_versions_immutable BEFORE UPDATE OR DELETE ON agreement_versions
  FOR EACH ROW EXECUTE FUNCTION prevent_changes();

CREATE TABLE agreement_acknowledgements (
  agreement_version_id  uuid NOT NULL,
  agreement_id          uuid NOT NULL,
  user_id               uuid NOT NULL REFERENCES users (id),
  acknowledged_at       timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (agreement_version_id, user_id),
  FOREIGN KEY (agreement_version_id, agreement_id) REFERENCES agreement_versions (id, agreement_id)
);

-- Only the two parties may acknowledge, only the current version, and the agreement
-- becomes 'acknowledged' once both have done so.
CREATE FUNCTION agreement_ack_before_insert() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  a  agreements%ROWTYPE;
  vn integer;
BEGIN
  SELECT * INTO a FROM agreements WHERE id = NEW.agreement_id FOR UPDATE;
  SELECT version_no INTO vn FROM agreement_versions WHERE id = NEW.agreement_version_id;
  IF NEW.user_id NOT IN (a.owner_id, a.counterparty_id) THEN
    RAISE EXCEPTION 'only the agreement parties can acknowledge' USING ERRCODE = 'check_violation';
  END IF;
  IF vn <> a.current_version_no OR a.status = 'cancelled' THEN
    RAISE EXCEPTION 'only the current version of an active agreement can be acknowledged'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;

CREATE FUNCTION agreement_ack_after_insert() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF (SELECT count(*) FROM agreement_acknowledgements
      WHERE agreement_version_id = NEW.agreement_version_id) = 2 THEN
    UPDATE agreements SET status = 'acknowledged' WHERE id = NEW.agreement_id;
  END IF;
  RETURN NULL;
END $$;

CREATE TRIGGER agreement_ack_insert BEFORE INSERT ON agreement_acknowledgements
  FOR EACH ROW EXECUTE FUNCTION agreement_ack_before_insert();
CREATE TRIGGER agreement_ack_complete AFTER INSERT ON agreement_acknowledgements
  FOR EACH ROW EXECUTE FUNCTION agreement_ack_after_insert();
CREATE TRIGGER agreement_ack_immutable BEFORE UPDATE OR DELETE ON agreement_acknowledgements
  FOR EACH ROW EXECUTE FUNCTION prevent_changes();

CREATE TABLE agreement_revision_requests (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agreement_id            uuid NOT NULL,
  based_on_version_id     uuid NOT NULL,
  requested_by            uuid NOT NULL REFERENCES users (id),
  reason                  text NOT NULL CHECK (char_length(reason) BETWEEN 1 AND 2000),
  status                  revision_status NOT NULL DEFAULT 'open',
  resolved_by_version_id  uuid,
  resolved_at             timestamptz,
  created_at              timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (based_on_version_id, agreement_id)    REFERENCES agreement_versions (id, agreement_id),
  FOREIGN KEY (resolved_by_version_id, agreement_id) REFERENCES agreement_versions (id, agreement_id),
  CONSTRAINT revision_resolved CHECK (status = 'open' OR resolved_at IS NOT NULL)
);
CREATE INDEX agreement_revisions_agreement_idx ON agreement_revision_requests (agreement_id, status);
