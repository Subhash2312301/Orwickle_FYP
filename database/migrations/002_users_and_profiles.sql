-- =====================================================================
-- Orwickle database — 002: users, auth tokens, profiles   (Feature 1)
-- =====================================================================

CREATE TABLE users (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email              text NOT NULL,
  password_hash      text NOT NULL,
  role               user_role NOT NULL,           -- chosen once at sign-up
  status             account_status NOT NULL DEFAULT 'active',
  email_verified_at  timestamptz,
  last_login_at      timestamptz,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  -- backend stores emails lower-cased
  CONSTRAINT users_email_format CHECK (email = lower(email) AND position('@' IN email) > 1),
  -- lets other tables enforce "this user has role X" with a composite FK
  CONSTRAINT users_id_role_key UNIQUE (id, role)
);
CREATE UNIQUE INDEX users_email_key ON users (email);

CREATE TRIGGER users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Refresh tokens, email verification and password reset tokens.
-- Only a hash of the token is stored, never the raw value.
CREATE TABLE auth_tokens (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  type        auth_token_type NOT NULL,
  token_hash  text NOT NULL UNIQUE,
  expires_at  timestamptz NOT NULL,
  used_at     timestamptz,                         -- consumed or revoked
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX auth_tokens_user_type_idx ON auth_tokens (user_id, type);

-- Common profile for every role.
CREATE TABLE profiles (
  user_id               uuid PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
  full_name             text NOT NULL CHECK (char_length(full_name) BETWEEN 2 AND 100),
  headline              text CHECK (char_length(headline) <= 150),
  bio                   text CHECK (char_length(bio) <= 2000),
  city                  text,
  avatar_path           text,                       -- path in Supabase Storage
  linkedin_url          text,
  website_url           text,
  -- evidence review (Feature 11); approved investor = "Investor Credentials Reviewed" badge
  review_status         review_status NOT NULL DEFAULT 'unreviewed',
  reviewed_at           timestamptz,
  -- cached count, maintained by trigger on deals (Feature 10)
  completed_deal_count  integer NOT NULL DEFAULT 0 CHECK (completed_deal_count >= 0),
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER profiles_updated_at BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Role-specific details. The (user_id, role) FK guarantees the user really has that role.
CREATE TABLE owner_profiles (
  user_id          uuid PRIMARY KEY,
  role             user_role NOT NULL DEFAULT 'owner' CHECK (role = 'owner'),
  university       text,
  degree_program   text,
  graduation_year  smallint CHECK (graduation_year BETWEEN 1990 AND 2100),
  skills           text[] NOT NULL DEFAULT '{}',
  github_url       text,
  portfolio_url    text,
  updated_at       timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (user_id, role) REFERENCES users (id, role) ON DELETE CASCADE
);

CREATE TABLE investor_profiles (
  user_id            uuid PRIMARY KEY,
  role               user_role NOT NULL DEFAULT 'investor' CHECK (role = 'investor'),
  investor_type      text CHECK (investor_type IN ('individual', 'angel', 'firm', 'other')),
  organization_name  text,
  min_ticket         numeric(14,2) CHECK (min_ticket >= 0),
  max_ticket         numeric(14,2) CHECK (max_ticket >= 0),
  currency           char(3) NOT NULL DEFAULT 'PKR',
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CHECK (max_ticket IS NULL OR min_ticket IS NULL OR max_ticket >= min_ticket),
  FOREIGN KEY (user_id, role) REFERENCES users (id, role) ON DELETE CASCADE
);

CREATE TABLE buyer_profiles (
  user_id          uuid PRIMARY KEY,
  role             user_role NOT NULL DEFAULT 'buyer' CHECK (role = 'buyer'),
  buyer_type       text CHECK (buyer_type IN ('individual', 'small_business', 'agency', 'other')),
  company_name     text,
  company_website  text,
  budget_min       numeric(14,2) CHECK (budget_min >= 0),
  budget_max       numeric(14,2) CHECK (budget_max >= 0),
  currency         char(3) NOT NULL DEFAULT 'PKR',
  updated_at       timestamptz NOT NULL DEFAULT now(),
  CHECK (budget_max IS NULL OR budget_min IS NULL OR budget_max >= budget_min),
  FOREIGN KEY (user_id, role) REFERENCES users (id, role) ON DELETE CASCADE
);

CREATE TRIGGER owner_profiles_updated_at BEFORE UPDATE ON owner_profiles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER investor_profiles_updated_at BEFORE UPDATE ON investor_profiles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER buyer_profiles_updated_at BEFORE UPDATE ON buyer_profiles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
