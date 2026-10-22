-- =====================================================================
-- Orwickle database — 009: reports and deal-completion badges   (Feature 10)
-- =====================================================================

CREATE TABLE reports (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id        uuid NOT NULL REFERENCES users (id),
  -- exactly one target
  target_user_id     uuid REFERENCES users (id),
  target_listing_id  uuid REFERENCES listings (id),
  target_message_id  uuid REFERENCES messages (id),
  reason             report_reason NOT NULL,
  details            text CHECK (char_length(details) <= 2000),
  status             report_status NOT NULL DEFAULT 'open',
  assigned_admin_id  uuid REFERENCES users (id),
  resolution_note    text,
  resolved_at        timestamptz,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT reports_one_target CHECK (num_nonnulls(target_user_id, target_listing_id, target_message_id) = 1),
  CONSTRAINT reports_not_self CHECK (target_user_id IS NULL OR target_user_id <> reporter_id),
  CONSTRAINT reports_resolved CHECK (status IN ('open', 'reviewing') OR resolved_at IS NOT NULL)
);
CREATE INDEX reports_queue_idx    ON reports (status, created_at) WHERE status IN ('open', 'reviewing');
CREATE INDEX reports_reporter_idx ON reports (reporter_id);

CREATE TRIGGER reports_updated_at BEFORE UPDATE ON reports
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- A deal follows an acknowledged agreement and completes when both parties confirm.
CREATE TABLE deals (
  id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agreement_id               uuid NOT NULL UNIQUE,
  listing_id                 uuid NOT NULL REFERENCES listings (id),
  owner_id                   uuid NOT NULL,
  counterparty_id            uuid NOT NULL,
  owner_confirmed_at         timestamptz,
  counterparty_confirmed_at  timestamptz,
  completed_at               timestamptz,
  cancelled_at               timestamptz,
  created_at                 timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (agreement_id, owner_id, counterparty_id)
    REFERENCES agreements (id, owner_id, counterparty_id),
  CONSTRAINT deals_completed_needs_both CHECK (
    completed_at IS NULL OR (owner_confirmed_at IS NOT NULL AND counterparty_confirmed_at IS NOT NULL)
  ),
  CONSTRAINT deals_not_both_states CHECK (completed_at IS NULL OR cancelled_at IS NULL)
);
CREATE INDEX deals_owner_idx        ON deals (owner_id);
CREATE INDEX deals_counterparty_idx ON deals (counterparty_id);

-- Sets completed_at once both have confirmed, increments both profiles' badge count,
-- and stops a completed deal from being reopened.
CREATE FUNCTION deals_before_update() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.completed_at IS NOT NULL THEN
    RAISE EXCEPTION 'deal % is already completed', OLD.id USING ERRCODE = 'restrict_violation';
  END IF;
  IF NEW.owner_confirmed_at IS NOT NULL AND NEW.counterparty_confirmed_at IS NOT NULL
     AND NEW.cancelled_at IS NULL THEN
    NEW.completed_at := now();
  END IF;
  RETURN NEW;
END $$;

CREATE FUNCTION deals_after_complete() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  UPDATE profiles SET completed_deal_count = completed_deal_count + 1
   WHERE user_id IN (NEW.owner_id, NEW.counterparty_id);
  RETURN NULL;
END $$;

CREATE TRIGGER deals_before_update BEFORE UPDATE ON deals
  FOR EACH ROW EXECUTE FUNCTION deals_before_update();
-- plain AFTER UPDATE (not "OF completed_at"): completed_at is set by the BEFORE trigger,
-- not by the UPDATE statement itself
CREATE TRIGGER deals_after_complete AFTER UPDATE ON deals
  FOR EACH ROW WHEN (OLD.completed_at IS NULL AND NEW.completed_at IS NOT NULL)
  EXECUTE FUNCTION deals_after_complete();
