// Accepts one image in the multipart field "image" (JPEG, PNG or WebP, up to 5 MB).
// The type is checked from the file's first bytes, not from the name the client sent.

const multer = require('multer');
const HttpError = require('../utils/httpError');

const MAX_BYTES = 5 * 1024 * 1024;

const SIGNATURES = [
  { type: 'image/jpeg', ext: 'jpg', test: b => b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff },
  { type: 'image/png', ext: 'png', test: b => b.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) },
  { type: 'image/webp', ext: 'webp', test: b => b.toString('ascii', 0, 4) === 'RIFF' && b.toString('ascii', 8, 12) === 'WEBP' },
];

const receive = multer({ storage: multer.memoryStorage(), limits: { fileSize: MAX_BYTES, files: 1 } }).single('image');

function imageUpload(req, res, next) {
  receive(req, res, err => {
    if (err?.code === 'LIMIT_FILE_SIZE') {
      return next(new HttpError(400, 'VALIDATION_ERROR', 'The image must be 5 MB or smaller', { image: 'The image must be 5 MB or smaller' }));
    }
    if (err) return next(new HttpError(400, 'VALIDATION_ERROR', 'Could not read the uploaded image', { image: err.message }));
    if (!req.file) {
      return next(new HttpError(400, 'VALIDATION_ERROR', 'Choose an image to upload', { image: 'Choose an image to upload' }));
    }
    const match = SIGNATURES.find(s => s.test(req.file.buffer));
    if (!match) {
      return next(new HttpError(400, 'VALIDATION_ERROR', 'Only JPEG, PNG or WebP images are allowed',
        { image: 'Only JPEG, PNG or WebP images are allowed' }));
    }
    req.image = { buffer: req.file.buffer, contentType: match.type, ext: match.ext };
    next();
  });
}

module.exports = imageUpload;
