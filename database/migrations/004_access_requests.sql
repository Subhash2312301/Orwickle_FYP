-- =====================================================================
-- Orwickle database — 004: connection / access requests   (Feature 4)
-- =====================================================================

CREATE TABLE access_requests (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id      uuid NOT NULL,
  listing_type    listing_type NOT NULL,
  owner_id        uuid NOT NULL,
  requester_id    uuid NOT NULL,
  requester_role  user_role NOT NULL,
  message         text CHECK (char_length(message) <= 1000),
  status          access_request_status NOT NULL DEFAULT 'pending',
  decision_note   text,
  decided_at      timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  -- owner and type must match the listing
  FOREIGN KEY (listing_id, owner_id)     REFERENCES listings (id, owner_id),
  FOREIGN KEY (listing_id, listing_type) REFERENCES listings (id, listing_type),
  FOREIGN KEY (requester_id, requester_role) REFERENCES users (id, role),
  -- investors request funding listings, buyers request sale listings
  CONSTRAINT access_requests_role_matches_type CHECK (
    (listing_type = 'funding' AND requester_role = 'investor') OR
    (listing_type = 'sale'    AND requester_role = 'buyer')
  ),
  CONSTRAINT access_requests_decided CHECK (status IN ('pending', 'withdrawn') OR decided_at IS NOT NULL),
  -- targets for composite FKs from offers, conversations and document grants
  CONSTRAINT access_requests_parties_key UNIQUE (id, listing_id, owner_id, requester_id),
  CONSTRAINT access_requests_id_listing_key UNIQUE (id, listing_id)
);

-- one active (pending or approved) request per requester per listing
CREATE UNIQUE INDEX access_requests_one_active_idx
  ON access_requests (listing_id, requester_id)
  WHERE status IN ('pending', 'approved');
CREATE INDEX access_requests_owner_idx     ON access_requests (owner_id, status);
CREATE INDEX access_requests_requester_idx ON access_requests (requester_id, status);

CREATE TRIGGER access_requests_updated_at BEFORE UPDATE ON access_requests
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
