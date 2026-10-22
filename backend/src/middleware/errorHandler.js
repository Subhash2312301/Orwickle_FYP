// Turns every error into one JSON shape: { error: { code, message, details? } }.
// Unexpected errors are logged and, in production, hidden behind a generic message.

const HttpError = require('../utils/httpError');
const env = require('../config/env');

function notFound(req, res, next) {
  next(new HttpError(404, 'NOT_FOUND', `Route ${req.method} ${req.originalUrl} does not exist`));
}

// eslint-disable-next-line no-unused-vars -- Express needs all four parameters
function errorHandler(err, req, res, next) {
  if (err instanceof HttpError) {
    return res.status(err.status).json({
      error: { code: err.code, message: err.message, details: err.details },
    });
  }

  // malformed JSON body
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({ error: { code: 'INVALID_JSON', message: 'Request body is not valid JSON' } });
  }

  console.error(err);
  return res.status(500).json({
    error: {
      code: 'INTERNAL_ERROR',
      message: env.isProduction ? 'Something went wrong' : err.message,
    },
  });
}

module.exports = { notFound, errorHandler };
