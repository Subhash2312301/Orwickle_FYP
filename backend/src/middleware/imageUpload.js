// Accepts one uploaded file (up to 5 MB). The type is checked from the file's first bytes,
// not from the name the client sent.
//   imageUpload    — field "image": JPEG, PNG or WebP (profile photos, listing covers)
//   documentUpload — field "file":  JPEG, PNG, WebP or PDF (CNIC, university ID, certificates)

const multer = require('multer');
const HttpError = require('../utils/httpError');

const MAX_BYTES = 5 * 1024 * 1024;

const SIGNATURES = [
  { type: 'image/jpeg', ext: 'jpg', test: b => b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff },
  { type: 'image/png', ext: 'png', test: b => b.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) },
  { type: 'image/webp', ext: 'webp', test: b => b.toString('ascii', 0, 4) === 'RIFF' && b.toString('ascii', 8, 12) === 'WEBP' },
  { type: 'application/pdf', ext: 'pdf', pdf: true, test: b => b.toString('ascii', 0, 5) === '%PDF-' },
];

function upload(field, { allowPdf }) {
  const receive = multer({ storage: multer.memoryStorage(), limits: { fileSize: MAX_BYTES, files: 1 } }).single(field);
  const allowed = allowPdf ? 'JPEG, PNG, WebP or PDF files' : 'JPEG, PNG or WebP images';
  const fail = (next, message) => next(new HttpError(400, 'VALIDATION_ERROR', message, { [field]: message }));

  return (req, res, next) => {
    receive(req, res, err => {
      if (err?.code === 'LIMIT_FILE_SIZE') return fail(next, 'The file must be 5 MB or smaller');
      if (err) return fail(next, 'Could not read the uploaded file');
      if (!req.file) return fail(next, 'Choose a file to upload');
      const match = SIGNATURES.find(s => (allowPdf || !s.pdf) && s.test(req.file.buffer));
      if (!match) return fail(next, `Only ${allowed} are allowed`);
      req.image = { buffer: req.file.buffer, contentType: match.type, ext: match.ext };
      next();
    });
  };
}

const imageUpload = upload('image', { allowPdf: false });
const documentUpload = upload('file', { allowPdf: true });

module.exports = imageUpload;
module.exports.documentUpload = documentUpload;
