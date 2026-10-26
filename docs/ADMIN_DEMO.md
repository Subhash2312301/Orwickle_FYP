# Admin dashboard demo (mid evaluation)

## Start everything
1. `cd backend && npm run dev` (API on http://localhost:4000)
2. `cd admin && npm run dev` (dashboard on http://localhost:5173)
3. The mobile app: phone APK, or `cd mobile && flutter run -d chrome --web-port 5050 --dart-define=API_BASE_URL=http://localhost:4000/api`

Admin login: the admin account created with `npm run create-admin` (email `orwickle.app+admin@gmail.com`).

## Demo story (about 5 minutes)
1. **Only admins get in.** Try logging in to the dashboard with an owner account → "Only administrators can use this dashboard."
2. **Overview.** Counts of owners, investors, buyers, accounts and listings waiting for review, locked and suspended accounts.
3. **Account review.** On the phone, register a new owner, verify the OTP, fill in the profile and upload the
   ID card → "Submit for review". In the dashboard, Overview shows 1 account waiting.
   Account reviews → open it → profile, links and documents (click to open full size) →
   "Review this account" → tick the checklist → Approve. The owner gets an email; in the app the
   "Account under review" banner disappears after pulling to refresh.
   Also show "Ask for more information" with a reason: the app shows the note and an "Update profile" button.
4. **Listing review.** The approved owner creates a listing with "Save & publish". Listing reviews → open it →
   public preview and confidential details side by side → checklist → Approve. The listing is now live.
   Reject instead sends it back to draft with the reason.
5. **Suspend.** Users → search the owner → Suspend with a reason. Within about 2 minutes the app logs out,
   and logging in again says "This account has been suspended". Reinstate → can log in again.
6. **Audit log.** Every decision above is listed with the admin, time and reason; the log cannot be edited.

## What the admin can do (v0.1)
| Area | Actions |
|---|---|
| Accounts | Approve, reject or ask for more information, with a per-role checklist; every decision is emailed and stored |
| Listings | Approve or reject (back to draft) published listings, with a checklist |
| Users | Search and filter, see profile, documents, listings and review history, suspend / reinstate |
| Audit log | Read-only history of admin decisions, logins and changes |

Later (FYP-II, Feature 11): verification badges, reports and moderation, offer and agreement monitoring.
