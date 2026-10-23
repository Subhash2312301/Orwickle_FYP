// /api/admin/* — administrators only. The React admin dashboard uses these.

const { Router } = require('express');
const validate = require('../../middleware/validate');
const { requireAuth, requireRole } = require('../../middleware/auth');
const baseUrl = require('../../utils/baseUrl');
const HttpError = require('../../utils/httpError');
const { userReviewSchema, listingReviewSchema } = require('./admin.validation');
const service = require('./admin.service');

const USER_QUEUES = ['pending', 'approved', 'rejected', 'needs_evidence'];
const LISTING_QUEUES = ['pending', 'approved'];

function queue(allowed) {
  return (req, res, next) => {
    req.queue = req.query.status || 'pending';
    if (!allowed.includes(req.queue)) return next(new HttpError(400, 'VALIDATION_ERROR', `status must be one of ${allowed.join(', ')}`));
    next();
  };
}

const router = Router();
router.use(requireAuth, requireRole('admin'));

router.get('/reviews/users', queue(USER_QUEUES), async (req, res) =>
  res.json(await service.listUserReviews(req.queue, baseUrl(req))));

router.post('/users/:id/review', validate(userReviewSchema), async (req, res) =>
  res.json(await service.reviewUser(req.user.id, req.params.id, req.body, { ip: req.ip })));

router.get('/reviews/listings', queue(LISTING_QUEUES), async (req, res) =>
  res.json(await service.listListingReviews(req.queue, req.user, baseUrl(req))));

router.post('/listings/:id/review', validate(listingReviewSchema), async (req, res) =>
  res.json(await service.reviewListing(req.user, req.params.id, req.body, { ip: req.ip, baseUrl: baseUrl(req) })));

module.exports = router;
