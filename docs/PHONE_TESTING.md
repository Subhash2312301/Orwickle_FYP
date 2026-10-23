# Testing Orwickle on a real Android phone

## Prepare the laptop (every time)
1. `ipconfig` → Wi-Fi IPv4 must match the IP the APK was built with (currently `192.168.18.247`).
   If it changed, rebuild: `flutter build apk --debug --dart-define=API_BASE_URL=http://<ip>:4000/api`.
2. `cd backend && npm run dev` — keep this terminal open (OTP emails are also printed here).
3. Once, in PowerShell **as Administrator**:
   `New-NetFirewallRule -DisplayName "Orwickle API 4000" -Direction Inbound -Protocol TCP -LocalPort 4000 -Action Allow -Profile Private`
4. Phone on the same Wi-Fi; open `http://<ip>:4000/api/health` in the phone's browser → `"status":"ok"`.

## Install
Copy `Orwickle-phone-test.apk` to the phone's Download folder (USB file transfer), open it, tap Install / Update.

Use Gmail "+" addresses for separate roles, e.g. `you+owner@gmail.com`, `you+investor@gmail.com`, `you+buyer@gmail.com`.

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
4. Profile setup: photo, skills, save.
5. Tabs Home / My Listings / Profile, and the "Account under review" banner.
6. New funding listing: equity % is required; add a cover photo.
7. Publish is disabled while the account is not approved.

**B. Approve on the laptop**
1. `npm run approve -- --email you+owner@gmail.com` → approval email arrives.
2. Pull to refresh on Profile → banner gone, status "Approved".
3. Publish the listing → "Waiting for admin review".
4. Run the approve command again → listing approved, email, Home shows "Live: 1".

**C. Rejection / more information**
1. `--more "Add your GitHub link"` → the note and an "Update profile" button appear.
2. Saving the profile puts it back "Under review".

**D. Investor and buyer**
1. Investor: Discover + Profile tabs; investment range chips required; no currency choice.
2. Buyer: headline example "Shop owner…"; budget optional.

**E. Security**
1. 5 wrong passwords in a row lock the account for 15 minutes.
2. Forgot password: OTP by email, new password works.
3. 15 minutes without touching the app → back to login with the inactivity message.
4. Profile → Change password works.

## Reporting a problem
Send the checklist number (e.g. "A-5"), a screenshot, and the last 10–15 lines of the backend terminal.

Note: photos are stored on the laptop until Supabase Storage is configured, so they only show while the backend is running.
