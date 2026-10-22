-- =====================================================================
-- Orwickle database — 010: evidence review, admin decisions, audit trail   (Feature 11)
-- =====================================================================

-- Evidence uploaded by an investor (about themselves) or an owner (about a listing).
CREATE TABLE evidence_submissions (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  submitted_by        uuid NOT NULL REFERENCES users (id),
  subject_user_id     uuid REFERENCES users (id),
  subject_listing_id  uuid REFERENCES listings (id),
  kind                text NOT NULL,     -- e.g. linkedin, company_registration, ownership_proof, github_repo
  description         text CHECK (char_length(description) <= 1000),
  storage_path        text,              -- file in the private bucket
  external_url        text,              -- or a link
  status              evidence_status NOT NULL DEFAULT 'pending',
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT evidence_one_subject CHECK (num_nonnulls(subject_user_id, subject_listing_id) = 1),
  CONSTRAINT evidence_has_content CHECK (storage_path IS NOT NULL OR external_url IS NOT NULL)
);
CREATE INDEX evidence_queue_idx   ON evidence_submissions (status, created_at) WHERE status = 'pending';
CREATE INDEX evidence_user_idx    ON evidence_submissions (subject_user_id);
CREATE INDEX evidence_listing_idx ON evidence_submissions (subject_listing_id);

CREATE TRIGGER evidence_updated_at BEFORE UPDATE ON evidence_submissions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Every admin decision with its reason and checklist; never edited.
CREATE TABLE review_decisions (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reviewer_id         uuid NOT NULL,
  reviewer_role       user_role NOT NULL DEFAULT 'admin' CHECK (reviewer_role = 'admin'),
  subject_user_id     uuid REFERENCES users (id),
  subject_listing_id  uuid REFERENCES listings (id),
  decision            review_decision_type NOT NULL,
  reason              text NOT NULL CHECK (char_length(reason) BETWEEN 1 AND 2000),
  checklist           jsonb NOT NULL DEFAULT '{}',
  evidence_ids        uuid[] NOT NULL DEFAULT '{}',
  created_at          timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (reviewer_id, reviewer_role) REFERENCES users (id, role),
  CONSTRAINT review_one_subject CHECK (num_nonnulls(subject_user_id, subject_listing_id) = 1)
);
CREATE INDEX review_decisions_user_idx    ON review_decisions (subject_user_id, created_at DESC);
CREATE INDEX review_decisions_listing_idx ON review_decisions (subject_listing_id, created_at DESC);

CREATE TRIGGER review_decisions_immutable BEFORE UPDATE OR DELETE ON review_decisions
  FOR EACH ROW EXECUTE FUNCTION prevent_changes();

-- Append-only audit trail of important actions (written by the backend).
CREATE TABLE audit_logs (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  actor_id     uuid REFERENCES users (id),      -- NULL = system job
  action       text NOT NULL,                   -- e.g. offer.accepted, document.opened, listing.suspended
  entity_type  text NOT NULL,
  entity_id    uuid,
  before       jsonb,
  after        jsonb,
  ip_address   inet,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX audit_logs_entity_idx ON audit_logs (entity_type, entity_id, created_at DESC);
CREATE INDEX audit_logs_actor_idx  ON audit_logs (actor_id, created_at DESC);

CREATE TRIGGER audit_logs_immutable BEFORE UPDATE OR DELETE ON audit_logs
  FOR EACH ROW EXECUTE FUNCTION prevent_changes();
