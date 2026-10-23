# Orwickle Backend

REST API for the Orwickle mobile app and admin dashboard: Node.js 22.9+, Express 5, PostgreSQL on Supabase.

## Run locally

```
cd backend
copy .env.example .env      # put the real DATABASE_URL in .env (same one as database/.env)
npm install
npm run dev                 # restarts automatically when a file in src/ changes
```

Check it works: open http://localhost:4000/api/health. You should see `"status":"ok","database":"connected"`.

Without `SMTP_USER` / `SMTP_PASS` in `.env`, OTP emails are printed in this terminal instead of being sent.

## Tests

```
npm test
```

Runs against the real Supabase database with `@test.orwickle.dev` accounts that are deleted afterwards.

## Auth API

| Method & path | Body | Result |
|---|---|---|
| `POST /api/auth/register` | `fullName, email, password, role` (owner / investor / buyer) | 201, OTP emailed |
| `POST /api/auth/verify-email` | `email, otp` | session (user is logged in) |
| `POST /api/auth/resend-otp` | `email, purpose` (email_verify / password_reset) | 200, or 429 `OTP_COOLDOWN` |
| `POST /api/auth/login` | `email, password` | session, or 403 `EMAIL_NOT_VERIFIED` |
| `POST /api/auth/refresh` | `refreshToken` | new session, or 401 `SESSION_EXPIRED` |
| `POST /api/auth/logout` | `refreshToken` | 204 |
| `POST /api/auth/forgot-password` | `email` | 200 (same answer for unknown emails) |
| `POST /api/auth/reset-password` | `email, otp, newPassword` | 200, all sessions ended |
| `GET /api/auth/me` | header `Authorization: Bearer <accessToken>` | current user |

A session is `{ accessToken, refreshToken, expiresIn: 900, user }`.

Rules (see `src/config/auth.js`):
- Access token lasts 15 minutes. A refresh token works once and is rejected after 15 minutes without use (inactivity) or 7 days in total. Reusing an old refresh token ends every session of that user.
- OTP: 6 digits, valid 10 minutes, 5 wrong attempts, one new code per minute. Only a hash is stored.
- Password: 8–72 characters with an uppercase letter, a lowercase letter and a number.
- Rate limits per IP: 10 logins and 15 OTP-related requests per 15 minutes.

## Structure

```
src/
  server.js              starts the server, clean shutdown
  app.js                 Express setup: security headers, CORS, JSON, logging, routes
  config/env.js          validates environment variables at startup
  db/pool.js             PostgreSQL pool + withTransaction() helper
  middleware/            404 and error handler (one JSON error shape)
  routes/health.js       GET /api/health
  utils/httpError.js     HttpError(status, code, message)
  modules/               one folder per feature (see modules/README.md)
```

## Error format

Every error response has the same shape, so the Flutter app can handle them in one place:

```json
{ "error": { "code": "NOT_FOUND", "message": "Route GET /api/x does not exist" } }
```

## Calling the API from the Flutter app

- Android emulator: `http://10.0.2.2:4000/api`
- Real phone on the same Wi-Fi: `http://<laptop IP from ipconfig>:4000/api`
