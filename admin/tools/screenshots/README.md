# Admin dashboard screenshots

Desktop screenshots (1440 × 900 at 2×) of every admin page, on realistic sample data.
Nothing touches the real backend or database: a small mock API answers in the same shapes.

Run from `admin/` (Google Chrome must be installed), each in its own terminal:

```
node tools/screenshots/mock_api.js 4100
set VITE_API_BASE_URL=http://localhost:4100/api&& npx vite --port 5174
node tools/screenshots/take_screenshots.js ../docs/screenshots/admin http://localhost:5174
```

Images go to `docs/screenshots/admin`. Stop the mock and the extra dev server afterwards.
