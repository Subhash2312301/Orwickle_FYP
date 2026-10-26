# Orwickle admin dashboard (v0.1)

React + Vite + Material UI. Talks only to the backend's `/api/admin/*` endpoints; it holds no database
or storage keys.

```
cd admin
npm install
npm run dev          # http://localhost:5173 (the backend must be running on :4000)
```

Point it at another backend with `admin/.env` (see `.env.example`): `VITE_API_BASE_URL=https://.../api`.

Pages: Overview, Account reviews, Listing reviews, Users (search, filters, detail, suspend/reinstate),
Audit log. Only accounts with the `admin` role can log in; 15 minutes without activity logs the admin out.

Demo script: [docs/ADMIN_DEMO.md](../docs/ADMIN_DEMO.md).
