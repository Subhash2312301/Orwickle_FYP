// An error with an HTTP status and a stable code the mobile app can check.
// Example: throw new HttpError(403, 'FORBIDDEN', 'Only the listing owner can do this');

class HttpError extends Error {
  constructor(status, code, message, details) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

module.exports = HttpError;
