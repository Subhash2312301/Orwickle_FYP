// Builds the Express application. Kept separate from server.js so tests can import it.

const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');

const env = require('./config/env');
const healthRoutes = require('./routes/health');
const authRoutes = require('./modules/auth/auth.routes');
const { notFound, errorHandler } = require('./middleware/errorHandler');

const app = express();

app.use(helmet());
app.use(cors({ origin: env.corsOrigin === '*' ? '*' : env.corsOrigin.split(',').map(s => s.trim()) }));
app.use(express.json({ limit: '1mb' }));
if (!env.isTest) app.use(morgan(env.isProduction ? 'combined' : 'dev'));

app.use('/api/health', healthRoutes);
app.use('/api/auth', authRoutes);

app.use(notFound);
app.use(errorHandler);

module.exports = app;
