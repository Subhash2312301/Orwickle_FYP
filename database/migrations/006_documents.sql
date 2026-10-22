-- =====================================================================
-- Orwickle database — 006: owner-controlled private documents   (Feature 6)
-- Files live in a private Supabase Storage bucket; this table holds metadata.
-- The backend returns a short-lived signed URL only when an active grant exists.
-- =====================================================================

CREATE TABLE documents (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id    uuid NOT NULL,
  owner_id      uuid NOT NULL,
  kind          document_kind NOT NULL,
  title         text NOT NULL CHECK (char_length(title) BETWEEN 1 AND 150),
  storage_path  text NOT NULL UNIQUE,
  file_name     text NOT NULL,
  mime_type     text NOT NULL CHECK (mime_type IN ('application/pdf', 'image/png', 'image/jpeg', 'image/webp')),
  size_bytes    bigint NOT NULL CHECK (size_bytes > 0 AND size_bytes <= 10485760),   -- 10 MB
  deleted_at    timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (listing_id, owner_id) REFERENCES listings (id, owner_id),
  CONSTRAINT documents_id_listing_key UNIQUE (id, listing_id)
);
CREATE INDEX documents_listing_idx ON documents (listing_id) WHERE deleted_at IS NULL;

-- Which approved requester may open which document.
CREATE TABLE document_grants (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id        uuid NOT NULL,
  listing_id         uuid NOT NULL,
  access_request_id  uuid NOT NULL,
  granted_at         timestamptz NOT NULL DEFAULT now(),
  revoked_at         timestamptz,
  -- document and request must belong to the same listing
  FOREIGN KEY (document_id, listing_id)       REFERENCES documents (id, listing_id),
  FOREIGN KEY (access_request_id, listing_id) REFERENCES access_requests (id, listing_id)
);

CREATE UNIQUE INDEX document_grants_active_idx
  ON document_grants (document_id, access_request_id) WHERE revoked_at IS NULL;
CREATE INDEX document_grants_request_idx ON document_grants (access_request_id);
