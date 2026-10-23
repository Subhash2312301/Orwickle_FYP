// Validates req.body against a zod schema and replaces it with the cleaned value.
// On failure responds 400 VALIDATION_ERROR with { field: message } details.

const HttpError = require('../utils/httpError');

function validate(schema) {
  return (req, res, next) => {
    const result = schema.safeParse(req.body ?? {});
    if (!result.success) {
      const details = {};
      for (const issue of result.error.issues) {
        const field = issue.path.join('.') || 'body';
        details[field] ??= issue.message;
      }
      return next(new HttpError(400, 'VALIDATION_ERROR', 'Please correct the highlighted fields', details));
    }
    req.body = result.data;
    next();
  };
}

module.exports = validate;
