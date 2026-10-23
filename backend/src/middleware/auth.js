// requireAuth: checks the "Authorization: Bearer <access token>" header and sets req.user = { id, role }.
// requireRole('owner', ...): allows only the listed roles. Always use after requireAuth.

const HttpError = require('../utils/httpError');
const { verifyAccessToken } = require('../modules/auth/tokens');

function requireAuth(req, res, next) {
  const header = req.get('authorization') || '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) {
    return next(new HttpError(401, 'UNAUTHENTICATED', 'Please log in to continue'));
  }
  try {
    req.user = verifyAccessToken(token);
    next();
  } catch {
    next(new HttpError(401, 'TOKEN_EXPIRED', 'Your session has expired, please log in again'));
  }
}

function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return next(new HttpError(403, 'FORBIDDEN', 'You do not have permission to do this'));
    }
    next();
  };
}

module.exports = { requireAuth, requireRole };
