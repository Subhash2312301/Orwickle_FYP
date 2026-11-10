// GET /api/health — confirms the server is running and can reach the database.

const { Router } = require('express');
const { pool } = require('../db/pool');

const router = Router();

// The mobile app looks for this name when it searches the Wi-Fi for the laptop running the backend.
const SERVICE = 'orwickle';

router.get('/', async (req, res) => {
  const started = Date.now();
  try {
    await pool.query('SELECT 1');
    res.json({
      service: SERVICE,
      status: 'ok',
      database: 'connected',
      dbLatencyMs: Date.now() - started,
      uptimeSeconds: Math.round(process.uptime()),
    });
  } catch (err) {
    console.error('Health check failed:', err.message);
    res.status(503).json({ service: SERVICE, status: 'error', database: 'unreachable' });
  }
});

module.exports = router;
