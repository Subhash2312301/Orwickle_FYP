// GET /api/files/<path>?expires=&sig= — serves locally stored files through signed, expiring links.
// Only used when Supabase Storage is not configured (development).

const { Router } = require('express');
const { local } = require('../services/storage');
const HttpError = require('../utils/httpError');

const router = Router();

router.get('/*filePath', (req, res, next) => {
  const filePath = [].concat(req.params.filePath).join('/');
  if (!local.verify(filePath, req.query.expires, req.query.sig)) {
    return next(new HttpError(403, 'LINK_EXPIRED', 'This link has expired'));
  }
  res.set('Cache-Control', 'private, max-age=3600');
  res.sendFile(local.resolve(filePath), { dotfiles: 'deny' }, err => {
    if (err) next(new HttpError(404, 'NOT_FOUND', 'File not found'));
  });
});

module.exports = router;
