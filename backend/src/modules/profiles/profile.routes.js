// /api/profile/* and /api/categories endpoints.

const { Router } = require('express');
const validate = require('../../middleware/validate');
const { requireAuth, requireRole } = require('../../middleware/auth');
const { profileSchemas } = require('./profile.validation');
const controller = require('./profile.controller');

const profileRouter = Router();
profileRouter.use(requireAuth);
profileRouter.get('/me', controller.getMine);
profileRouter.put(
  '/me',
  requireRole('owner', 'investor', 'buyer'),
  (req, res, next) => validate(profileSchemas[req.user.role])(req, res, next),
  controller.updateMine,
);

const categoryRouter = Router();
categoryRouter.get('/', controller.categories);

module.exports = { profileRouter, categoryRouter };
