// Request body rules for the auth endpoints. The Flutter forms apply the same rules.

const { z } = require('zod');

const required = label => ({ error: `${label} is required` });

const email = z.string(required('Email'))
  .trim()
  .toLowerCase()
  .max(254, 'Email is too long')
  .pipe(z.email('Enter a valid email address'));

const password = z.string(required('Password'))
  .min(8, 'Password must be at least 8 characters')
  .max(72, 'Password must be at most 72 characters')
  .regex(/[A-Z]/, 'Password must contain an uppercase letter')
  .regex(/[a-z]/, 'Password must contain a lowercase letter')
  .regex(/[0-9]/, 'Password must contain a number');

const otp = z.string(required('Code'))
  .trim()
  .regex(/^\d{6}$/, 'Enter the 6-digit code');

const refreshToken = z.string(required('Refresh token')).min(20).max(200);

const registerSchema = z.object({
  fullName: z.string(required('Full name'))
    .trim()
    .min(2, 'Full name must be at least 2 characters')
    .max(100, 'Full name must be at most 100 characters'),
  email,
  password,
  role: z.enum(['owner', 'investor', 'buyer'], { error: 'Choose Project Owner, Investor or Buyer' }),
});

const verifyEmailSchema = z.object({ email, otp });

const resendOtpSchema = z.object({
  email,
  purpose: z.enum(['email_verify', 'password_reset'], { error: 'Invalid purpose' }),
});

// login checks only presence, so old passwords that predate a rule change still work
const loginSchema = z.object({
  email,
  password: z.string(required('Password')).min(1, 'Password is required').max(72),
});

const refreshSchema = z.object({ refreshToken });

const forgotPasswordSchema = z.object({ email });

const resetPasswordSchema = z.object({ email, otp, newPassword: password });

module.exports = {
  registerSchema,
  verifyEmailSchema,
  resendOtpSchema,
  loginSchema,
  refreshSchema,
  forgotPasswordSchema,
  resetPasswordSchema,
};
