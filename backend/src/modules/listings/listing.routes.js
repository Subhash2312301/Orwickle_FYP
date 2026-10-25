// /api/listings/* endpoints. Every route needs a login; changes are for project owners only,
// and the service makes sure an owner can only change their own listings.

const { Router } = require('express');
const validate = require('../../middleware/validate');
const imageUpload = require('../../middleware/imageUpload');
const { requireAuth, requireRole } = require('../../middleware/auth');
const { listingSchema } = require('./listing.validation');
const controller = require('./listing.controller');

const router = Router();
const ownerOnly = requireRole('owner');

router.use(requireAuth);
router.post('/', ownerOnly, validate(listingSchema), controller.create);
router.get('/mine', ownerOnly, controller.mine);
router.get('/:id', controller.get);
router.put('/:id', ownerOnly, validate(listingSchema), controller.update);
router.post('/:id/publish', ownerOnly, controller.publish);
router.post('/:id/unpublish', ownerOnly, controller.unpublish);
router.post('/:id/close', ownerOnly, controller.close);
router.delete('/:id', ownerOnly, controller.remove);
router.put('/:id/cover', ownerOnly, imageUpload, controller.setCover);
router.delete('/:id/cover', ownerOnly, controller.removeCover);
router.post('/:id/photos', ownerOnly, imageUpload, controller.addPhoto);
router.delete('/:id/photos/:photoId', ownerOnly, controller.removePhoto);

module.exports = router;
