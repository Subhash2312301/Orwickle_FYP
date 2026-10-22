-- =====================================================================
-- Orwickle database — 005: bidding — offers and offer versions   (Feature 5)
-- An offer is a one-to-one negotiation thread between the owner and one bidder.
-- Every offer / counteroffer is a new row in offer_versions; terms never change.
-- =====================================================================

CREATE TABLE offers (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  access_request_id    uuid NOT NULL,
  listing_id           uuid NOT NULL,
  owner_id             uuid NOT NULL,
  bidder_id            uuid NOT NULL,
  offer_type           listing_type NOT NULL,       -- funding offer or purchase offer
  status               offer_status NOT NULL DEFAULT 'open',
  accepted_version_id  uuid,                         -- FK added below
  closed_at            timestamptz,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  -- parties must be exactly the owner and requester of the access request
  FOREIGN KEY (access_request_id, listing_id, owner_id, bidder_id)
    REFERENCES access_requests (id, listing_id, owner_id, requester_id),
  FOREIGN KEY (listing_id, offer_type) REFERENCES listings (id, listing_type),
  CONSTRAINT offers_closed CHECK (status = 'open' OR closed_at IS NOT NULL),
  CONSTRAINT offers_accepted_has_version CHECK (status <> 'accepted' OR accepted_version_id IS NOT NULL),
  CONSTRAINT offers_id_type_key UNIQUE (id, offer_type)
);

-- each bidder has at most one open negotiation per listing
CREATE UNIQUE INDEX offers_one_open_per_bidder_idx
  ON offers (listing_id, bidder_id) WHERE status = 'open';
CREATE INDEX offers_owner_idx  ON offers (owner_id, status);
CREATE INDEX offers_bidder_idx ON offers (bidder_id, status);

CREATE TRIGGER offers_updated_at BEFORE UPDATE ON offers
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE offer_versions (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  offer_id             uuid NOT NULL,
  offer_type           listing_type NOT NULL,
  version_no           integer NOT NULL CHECK (version_no > 0),   -- assigned by trigger
  proposed_by          uuid NOT NULL REFERENCES users (id),
  recipient_id         uuid NOT NULL REFERENCES users (id),      -- only this user may respond
  amount               numeric(14,2) NOT NULL CHECK (amount > 0),
  currency             char(3) NOT NULL DEFAULT 'PKR',
  equity_percent       numeric(5,2) CHECK (equity_percent > 0 AND equity_percent <= 100),  -- funding
  deliverables         text,                                       -- sale
  transfer_conditions  text,                                       -- sale
  conditions           text,
  message              text CHECK (char_length(message) <= 1000),
  expires_at           timestamptz NOT NULL,
  status               offer_version_status NOT NULL DEFAULT 'pending',
  responded_at         timestamptz,
  response_note        text,
  created_at           timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (offer_id, offer_type) REFERENCES offers (id, offer_type),
  CONSTRAINT offer_versions_parties_differ CHECK (proposed_by <> recipient_id),
  CONSTRAINT offer_versions_expiry CHECK (expires_at > created_at),
  CONSTRAINT offer_versions_terms_by_type CHECK (
    (offer_type = 'funding' AND equity_percent IS NOT NULL) OR
    (offer_type = 'sale'    AND equity_percent IS NULL AND deliverables IS NOT NULL)
  ),
  CONSTRAINT offer_versions_responded CHECK (status = 'pending' OR responded_at IS NOT NULL),
  CONSTRAINT offer_versions_no_key UNIQUE (offer_id, version_no),
  CONSTRAINT offer_versions_id_offer_key UNIQUE (id, offer_id)
);
-- only one version awaiting a response at a time
CREATE UNIQUE INDEX offer_versions_one_pending_idx ON offer_versions (offer_id) WHERE status = 'pending';
CREATE INDEX offer_versions_recipient_idx ON offer_versions (recipient_id) WHERE status = 'pending';

-- accepted version must belong to the same offer
ALTER TABLE offers
  ADD CONSTRAINT offers_accepted_version_fk
  FOREIGN KEY (accepted_version_id, id) REFERENCES offer_versions (id, offer_id);

-- Before insert: check both parties belong to the offer and assign the next version_no.
CREATE FUNCTION offer_versions_before_insert() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  o offers%ROWTYPE;
BEGIN
  SELECT * INTO o FROM offers WHERE id = NEW.offer_id FOR UPDATE;
  IF o.status <> 'open' THEN
    RAISE EXCEPTION 'offer % is %, no new versions allowed', o.id, o.status
      USING ERRCODE = 'check_violation';
  END IF;
  IF NOT (NEW.proposed_by IN (o.owner_id, o.bidder_id)
          AND NEW.recipient_id IN (o.owner_id, o.bidder_id)) THEN
    RAISE EXCEPTION 'offer version parties must be the offer owner and bidder'
      USING ERRCODE = 'check_violation';
  END IF;
  SELECT coalesce(max(version_no), 0) + 1 INTO NEW.version_no
    FROM offer_versions WHERE offer_id = NEW.offer_id;
  RETURN NEW;
END $$;

CREATE TRIGGER offer_versions_insert BEFORE INSERT ON offer_versions
  FOR EACH ROW EXECUTE FUNCTION offer_versions_before_insert();

-- Before update/delete: terms are frozen; only a pending version's status may change, once.
CREATE FUNCTION offer_versions_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'offer versions cannot be deleted' USING ERRCODE = 'restrict_violation';
  END IF;
  IF OLD.status <> 'pending' THEN
    RAISE EXCEPTION 'offer version % is already %', OLD.id, OLD.status USING ERRCODE = 'restrict_violation';
  END IF;
  IF (NEW.offer_id, NEW.offer_type, NEW.version_no, NEW.proposed_by, NEW.recipient_id, NEW.amount,
      NEW.currency, NEW.equity_percent, NEW.deliverables, NEW.transfer_conditions, NEW.conditions,
      NEW.message, NEW.expires_at, NEW.created_at)
     IS DISTINCT FROM
     (OLD.offer_id, OLD.offer_type, OLD.version_no, OLD.proposed_by, OLD.recipient_id, OLD.amount,
      OLD.currency, OLD.equity_percent, OLD.deliverables, OLD.transfer_conditions, OLD.conditions,
      OLD.message, OLD.expires_at, OLD.created_at) THEN
    RAISE EXCEPTION 'offer terms are immutable; create a new version instead' USING ERRCODE = 'restrict_violation';
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER offer_versions_guard BEFORE UPDATE OR DELETE ON offer_versions
  FOR EACH ROW EXECUTE FUNCTION offer_versions_guard();
