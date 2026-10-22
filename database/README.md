# Orwickle Database

PostgreSQL schema for Orwickle, hosted on Supabase. It covers all 11 features of FYP-I and FYP-II, so no structural changes are needed when FYP-II starts.

## Files

| File | Contents | Feature |
|---|---|---|
| `migrations/001_types_and_helpers.sql` | Enum types, `updated_at` and append-only helper triggers | — |
| `migrations/002_users_and_profiles.sql` | users, auth_tokens, profiles, owner/investor/buyer profiles | 1 |
| `migrations/003_categories_and_listings.sql` | categories, interests, listings (public preview), listing_confidential | 2, 3 |
| `migrations/004_access_requests.sql` | access_requests | 4 |
| `migrations/005_offers.sql` | offers, offer_versions (immutable terms) | 5 |
| `migrations/006_documents.sql` | documents, document_grants | 6 |
| `migrations/007_chat_and_notifications.sql` | conversations, messages, notifications | 7, 8 |
| `migrations/008_agreements.sql` | agreements, agreement_versions, acknowledgements, revision requests | 9 |
| `migrations/009_reports_and_deals.sql` | reports, deals (+ completed-deal count trigger) | 10 |
| `migrations/010_evidence_review_and_audit.sql` | evidence_submissions, review_decisions, audit_logs | 11 |
| `migrations/011_security.sql` | Enables RLS on every table, blocks Supabase's public API | — |
| `seeds/001_categories.sql` | Project categories | — |

27 tables in total.

## Rules enforced by the database itself

- A user has exactly one role, and role-specific rows (owner profile, listing, investor request, admin decision) only accept users with the matching role.
- Investors can only request funding listings; buyers can only request sale listings.
- One active access request per user per listing, and one open offer per bidder per listing.
- Offer and agreement terms can never be edited or deleted. Every change is a new version, and version numbers are assigned automatically.
- Only the two parties can send messages in a conversation, respond to offer versions, or acknowledge an agreement, and only the current agreement version can be acknowledged.
- Documents can only be granted to access requests for the same listing.
- `completed_deal_count` goes up for both parties only when both have confirmed the deal, and a completed deal cannot be reopened.
- Admin decisions and audit logs are append-only.

Business rules that depend on the logged-in user (for example "only the recipient may accept this offer", "access request must be approved before an offer") are checked by the Node.js backend.

## Applying the schema to Supabase (only once per Supabase project)

1. Open the Supabase project → **SQL Editor** → **New query**.
2. Paste and run each file in `migrations/` **in number order** (001 → 011), then `seeds/001_categories.sql`.
3. Check **Table Editor**: 27 tables should appear, each with RLS enabled.

Later schema changes go into new numbered files (`012_...sql`), never into edits of files that have already been run.

The database lives in the cloud, so this is done once. Switching laptops does not require running it again.

## Running the project on another laptop

The database is on Supabase, so it does not move. Every laptop connects to the same Supabase project over the internet. Only the code and the secret `.env` file have to be brought to the other laptop.

### 1. Install software (same versions on both laptops)

| Tool | Version |
|---|---|
| Git | latest |
| Node.js | 24.x (LTS), same as the main laptop |
| Flutter SDK | same version on both (`flutter --version`) |
| Android Studio + Android SDK + an emulator | latest |
| VS Code with Flutter, Dart and PostgreSQL extensions | latest |
| Postman | latest |

### 2. Get the code through GitHub

- Push the project to a **private** GitHub repository from the main laptop, and add the teammate as a collaborator.
- On the other laptop: `git clone <repo-url>` into a normal folder such as `C:\Projects\Orwickle`. Keep it **outside OneDrive**, because OneDrive syncing `node_modules` and Flutter `build` folders causes file locks and slow builds.
- Never copy `node_modules` or `build` folders between laptops. Recreate them with `npm install` and `flutter pub get`.

### 3. Connect to the same database

- Add the teammate to the Supabase organization (**Organization settings → Team → Invite**), so they can open the dashboard with their own login.
- Copy the backend's `.env` file to the other laptop **privately** (never through GitHub). The repository keeps only `.env.example` with empty values. The `.env` will hold:
  - `DATABASE_URL`: Supabase → Project Settings → Database → Connection string
  - `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`: for private Storage
  - `JWT_SECRET`: must be **identical** on every laptop, otherwise tokens issued on one will fail on the other
- Do **not** run the migrations again. The tables already exist.

### 4. Point the mobile app at that laptop's backend

The Flutter app's API base URL changes per machine:

- Android emulator → `http://10.0.2.2:<port>`
- Physical phone on the same Wi-Fi → `http://<that laptop's IP>:<port>` (find it with `ipconfig`)
- Deployed backend → its public URL, which is the same on every laptop

### 5. Daily workflow for two developers

- `git pull` before starting, work on a separate branch per feature, then push and merge.
- If someone adds a new migration file, run it once in the Supabase SQL Editor and tell the other person.
