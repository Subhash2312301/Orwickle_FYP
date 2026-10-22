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
