# Orwickle admin dashboard (v0.1)

React + Vite + Material UI. Talks only to the backend's `/api/admin/*` endpoints; it holds no database
or storage keys.

```
cd admin
npm install
npm run dev          # http://localhost:5173 (the backend must be running on :4000)
```

Point it at another backend with `admin/.env` (see `.env.example`): `VITE_API_BASE_URL=https://.../api`.

Pages: Overview, Investor verification, Project verification, Owners & buyers (account verification),
Users (search, filters, detail, suspend/reinstate), Verification history (who reviewed what, when, the
decision, the reason and the evidence reviewed) and Audit log. Only accounts with the `admin` role can log in;
15 minutes without activity logs the admin out.

Verification statuses: Pending → Under Review (an admin started the review) → Verified / Rejected /
More evidence requested (→ Expired after 30 days without an answer); Suspended comes from the account.

Demo script: [docs/ADMIN_DEMO.md](../docs/ADMIN_DEMO.md).
