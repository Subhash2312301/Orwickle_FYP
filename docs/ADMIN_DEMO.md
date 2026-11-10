# Admin dashboard demo (mid evaluation)

## Start everything
1. `cd backend && npm run dev` (API on http://localhost:4000)
2. `cd admin && npm run dev` (dashboard on http://localhost:5173)
3. The mobile app: phone APK, or `cd mobile && flutter run -d chrome --web-port 5050 --dart-define=API_BASE_URL=http://localhost:4000/api`

Admin login: the admin account created with `npm run create-admin` (email `orwickle.app+admin@gmail.com`).

## Demo story (about 5 minutes)
1. **Only admins get in.** Try logging in to the dashboard with an owner account → "Only administrators can use this dashboard."
2. **Overview.** Investors and projects waiting for verification, and every verification status: Pending,
   Under Review, More evidence requested, Verified, Rejected, Suspended, Expired (each card opens the list).
3. **Investor verification.** On the phone, register a new investor, verify the OTP, fill in organization,
   designation, LinkedIn, interests, stages, range and sectors, and add at least two pieces of evidence (a file or
   a link each) → "Submit for review". In the dashboard: Investor verification → open it → identity, professional
   information and supporting evidence → "Start review" (status becomes Under Review) → tick the checklist →
   Approve. The app now shows "Profile Verified" (the evidence was checked; not a guaranteed investor).
   Also show "Request more evidence" with a reason: the app shows the note and the 30-day limit.
4. **Project verification.** A verified owner creates a listing, adds ownership evidence (e.g. the GitHub
   repository) and uses "Save & publish". Project verification → open it → owner information, ownership and
   project evidence, claims requiring review, public preview → "Start review" → checklist → Approve, Request
   changes or Reject (the last two send it back to draft with the reason).
5. **Owners & buyers.** Same flow for owner and buyer accounts (ID card checks).
6. **Suspend.** Users → search the owner → Suspend with a reason. Within about 2 minutes the app logs out,
   and logging in again says "This account has been suspended". Reinstate → can log in again.
7. **Verification history.** Every decision with the reviewer, time, decision, reason and the evidence reviewed;
   decisions cannot be edited. The Audit log lists everything else (logins, changes, expiries).

## What the admin can do
| Area | Actions |
|---|---|
| Investor verification | Identity, professional information and evidence; approve, reject or request more evidence, with a checklist |
| Project verification | Owner, ownership and project evidence, claims; approve, reject or request changes, with a checklist |
| Owners & buyers | Approve, reject or request more evidence, with a per-role checklist |
| Statuses | Pending, Under Review, Verified, Rejected, Suspended, Expired (no answer to a request within 30 days) |
| Users | Search and filter by role and status, see profile, documents, listings and review history, suspend / reinstate |
| Verification history | Who reviewed it, when, decision, reason, evidence reviewed |
| Audit log | Read-only history of admin decisions, logins and changes |

Later (FYP-II): reports (fake profile, misleading project, impersonation, suspicious communication),
offer and agreement monitoring.
