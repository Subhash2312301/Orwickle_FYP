// /api/auth/* endpoints.

const { Router } = require('express');
const validate = require('../../middleware/validate');
const { requireAuth } = require('../../middleware/auth');
const { loginLimiter, otpLimiter } = require('../../middleware/rateLimits');
const schemas = require('./auth.validation');
const controller = require('./auth.controller');

const router = Router();

router.post('/register', otpLimiter, validate(schemas.registerSchema), controller.register);
router.post('/verify-email', otpLimiter, validate(schemas.verifyEmailSchema), controller.verifyEmail);
router.post('/resend-otp', otpLimiter, validate(schemas.resendOtpSchema), controller.resendOtp);
router.post('/login', loginLimiter, validate(schemas.loginSchema), controller.login);
router.post('/refresh', validate(schemas.refreshSchema), controller.refresh);
router.post('/logout', validate(schemas.refreshSchema), controller.logout);
router.post('/forgot-password', otpLimiter, validate(schemas.forgotPasswordSchema), controller.forgotPassword);
router.post('/reset-password', otpLimiter, validate(schemas.resetPasswordSchema), controller.resetPassword);
router.get('/me', requireAuth, controller.me);

module.exports = router;
