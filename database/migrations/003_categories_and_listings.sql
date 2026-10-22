-- =====================================================================
-- Orwickle database — 003: categories and listings   (Features 2, 3)
-- Public preview (listings) and confidential details (listing_confidential)
-- are separate tables so a preview query can never return confidential fields.
-- =====================================================================

CREATE TABLE categories (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL UNIQUE,
  slug        text NOT NULL UNIQUE CHECK (slug ~ '^[a-z0-9-]+$'),
  is_active   boolean NOT NULL DEFAULT true,
  sort_order  smallint NOT NULL DEFAULT 0
);

-- Categories an investor or buyer is interested in (used for discovery filters).
CREATE TABLE user_category_interests (
  user_id      uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  category_id  uuid NOT NULL REFERENCES categories (id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, category_id)
);

-- Public preview of a project.
CREATE TABLE listings (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id           uuid NOT NULL,
  owner_role         user_role NOT NULL DEFAULT 'owner' CHECK (owner_role = 'owner'),
  listing_type       listing_type NOT NULL,         -- 'funding' = Seeking Funding, 'sale' = Available for Purchase
  category_id        uuid NOT NULL REFERENCES categories (id),
  title              text NOT NULL CHECK (char_length(title) BETWEEN 3 AND 120),
  short_description  text NOT NULL CHECK (char_length(short_description) BETWEEN 10 AND 500),
  tech_stack         text[] NOT NULL DEFAULT '{}',
  project_stage      project_stage NOT NULL DEFAULT 'prototype',
  asking_amount      numeric(14,2) CHECK (asking_amount >= 0),   -- funding goal or sale price
  currency           char(3) NOT NULL DEFAULT 'PKR',
  thumbnail_path     text,                                        -- preview image in Storage
  status             listing_status NOT NULL DEFAULT 'draft',
  -- evidence review (Feature 11); approved = "Project Evidence Reviewed" badge
  review_status      review_status NOT NULL DEFAULT 'unreviewed',
  reviewed_at        timestamptz,
  published_at       timestamptz,
  closed_at          timestamptz,
  search_vector      tsvector GENERATED ALWAYS AS (
                       setweight(to_tsvector('simple', coalesce(title, '')), 'A') ||
                       setweight(to_tsvector('simple', coalesce(short_description, '')), 'B')
                     ) STORED,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (owner_id, owner_role) REFERENCES users (id, role),
  -- targets for composite FKs in later tables
  CONSTRAINT listings_id_owner_key UNIQUE (id, owner_id),
  CONSTRAINT listings_id_type_key  UNIQUE (id, listing_type)
);
CREATE INDEX listings_discovery_idx ON listings (listing_type, status, category_id, published_at DESC);
CREATE INDEX listings_owner_idx     ON listings (owner_id);
CREATE INDEX listings_search_idx    ON listings USING gin (search_vector);
CREATE INDEX listings_review_idx    ON listings (review_status) WHERE review_status = 'pending';

CREATE TRIGGER listings_updated_at BEFORE UPDATE ON listings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Confidential details, released only after the owner approves an access request.
CREATE TABLE listing_confidential (
  listing_id              uuid PRIMARY KEY REFERENCES listings (id) ON DELETE CASCADE,
  full_description        text,
  problem_statement       text,
  solution_details        text,
  business_model          text,
  traction                text,
  financial_summary       text,
  equity_offered_percent  numeric(5,2) CHECK (equity_offered_percent > 0 AND equity_offered_percent <= 100),
  ip_ownership_notes      text,
  transfer_details        text,     -- sale listings: what the buyer receives
  roadmap                 text,
  team_details            text,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER listing_confidential_updated_at BEFORE UPDATE ON listing_confidential
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
