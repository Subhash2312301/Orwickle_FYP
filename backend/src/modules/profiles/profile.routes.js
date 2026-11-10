// /api/profile/* and /api/categories endpoints.

const { Router } = require('express');
const validate = require('../../middleware/validate');
const imageUpload = require('../../middleware/imageUpload');
const { documentUpload } = imageUpload;
const { requireAuth, requireRole } = require('../../middleware/auth');
const { profileSchemas, evidenceLinkSchema } = require('./profile.validation');
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
profileRouter.put('/me/avatar', imageUpload, controller.setAvatar);
profileRouter.delete('/me/avatar', controller.removeAvatar);
// verification documents: owner/buyer ID cards, investor evidence (multipart field "file"),
// or investor evidence as a link ({ "url": "https://..." })
profileRouter.put('/me/documents/:kind', requireRole('owner', 'investor', 'buyer'), documentUpload, controller.setDocument);
profileRouter.put('/me/documents/:kind/link', requireRole('investor'), validate(evidenceLinkSchema), controller.setDocumentLink);
profileRouter.delete('/me/documents/:kind', requireRole('owner', 'investor', 'buyer'), controller.removeDocument);

const categoryRouter = Router();
categoryRouter.get('/', controller.categories);

module.exports = { profileRouter, categoryRouter };
