# Testing Orwickle on a real Android phone

## Prepare the laptop (every time)
1. Laptop and phone on the same Wi-Fi or on the phone's hotspot. No IP address needs typing or rebuilding:
   the app tries the last address that worked, and if nothing answers it searches the phone's network
   (x.x.x.1–254, port 4000) for `/api/health` answering `"service":"orwickle"` and saves it. This also
   runs whenever the app is opened again. If it cannot find the laptop, long-press the logo on the
   login / welcome screen to type the address by hand.
2. `cd backend && npm run dev` — keep this terminal open (OTP emails are also printed here).
3. Once, in PowerShell **as Administrator**:
   `New-NetFirewallRule -DisplayName "Orwickle API 4000" -Direction Inbound -Protocol TCP -LocalPort 4000 -Action Allow -Profile Private`
   On a new Wi-Fi, Windows may mark it Public: set it to Private (Settings → Network → Wi-Fi → network
   profile), otherwise the firewall blocks the phone.
4. University, office and café Wi-Fi often stops devices from reaching each other (client isolation).
   There nothing on the network can reach the laptop; use the phone's hotspot instead.
5. Check from the phone's browser: `http://<laptop ip>:4000/api/health` → `"service":"orwickle"`.

## Install
Copy `Orwickle-phone-test.apk` to the phone's Download folder (USB file transfer), open it, tap Install / Update.

Use Gmail "+" addresses for separate roles, e.g. `you+owner@gmail.com`, `you+investor@gmail.com`, `you+buyer@gmail.com`.

## Demo data
`npm run seed:demo` creates 6 approved sample users and 6 approved sample listings (badge "Sample").
Log in as `ayesha@demo.orwickle.app` (owner), `farhan@demo.orwickle.app` (investor) or `imran@demo.orwickle.app`
(buyer), password `Demo#Orwickle26`. `npm run seed:demo -- --remove` deletes them.

## Approve accounts and listings (until the admin dashboard exists)
```
npm run approve -- --email you+owner@gmail.com                   # approve account + its pending listings
npm run approve -- --email you+owner@gmail.com --reject "reason"
npm run approve -- --email you+owner@gmail.com --more "what is missing"
```

## Checklist
**A. Owner**
1. Register; a weak password (`Pakistan@123`) is refused.
2. "Create account" without ticking the terms shows an error.
3. OTP arrives by email; a wrong code shows "4 attempts left"; the right code continues.
4. Profile setup: bio, LinkedIn, GitHub and portfolio are required, website optional, no city, no graduation year.
   "University student" → university, degree and university ID card front + back required;
   "Independent developer" → CNIC front + back required instead. Then "Submit for review".
5. Tabs Home / My Listings / Requests / Messages / Profile, and the "Account under review" banner.
   Requests, Messages and the bell show "Coming soon".
6. New funding listing: equity %, full description, problem statement, business model, financial summary and
   ownership notes are required (no solution, traction, roadmap or team). Add up to 6 photos.
7. "Save & publish" is disabled while the account is not approved; "Save as draft" works.

**B. Approve on the laptop**
1. `npm run approve -- --email you+owner@gmail.com` → approval email arrives.
2. Pull to refresh on Profile → banner gone, status "Approved".
3. Publish the listing (or create a new one with "Save & publish") → "Waiting for admin review".
4. Run the approve command again → listing approved, email, Home shows "Live: 1".

**C. Rejection / more information**
1. `--more "Add your GitHub link"` → the note and an "Update profile" button appear.
2. Saving the profile puts it back "Under review".

**D. Investor and buyer**
1. Investor: organization, professional designation, LinkedIn, investment interests, investment stage,
   range chips and sector preferences — all required; company website optional. No CNIC, phone, city or headline.
2. Evidence step: at least 2 of company registration, VC / angel network, accelerator / incubator,
   investment portfolio, professional credentials. Each can be a photo, a PDF or a link.
3. Profile tab shows "designation · organization"; once approved the status is "Profile Verified".
4. Buyer: phone and LinkedIn required; University or Company; Company → company name and company email;
   University → university ID front + back. No headline, website or budget.
   Discover says "projects", not "software projects".
5. Replacing a document after approval puts the account back "Under review".
6. Requests and Messages tabs show "Coming soon".

**F. Listing photos**
1. On the listing page add and remove photos (max 6); tap a photo to see it full screen.
2. On a live listing, changing the cover or photos first warns that it goes back to admin review.

**E. Security**
1. 5 wrong passwords in a row lock the account for 15 minutes.
2. Forgot password: OTP by email, new password works.
3. 15 minutes without touching the app → back to login with the inactivity message.
4. Profile → Change password works.
5. Log out asks "Are you sure you want to log out?"; Cancel keeps you logged in.

## Reporting a problem
Send the checklist number (e.g. "A-5"), a screenshot, and the last 10–15 lines of the backend terminal.

Note: photos are stored on the laptop until Supabase Storage is configured, so they only show while the backend is running.
