/// Form rules. They match the backend's rules (backend/src/modules/auth/auth.validation.js),
/// so most mistakes are caught before a request is sent.
class Validators {
  const Validators._();

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _otpPattern = RegExp(r'^\d{6}$');

  static String? fullName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Full name is required';
    if (v.length < 2) return 'Full name must be at least 2 characters';
    if (v.length > 100) return 'Full name must be at most 100 characters';
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (v.length > 254 || !_emailPattern.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  /// Full strength rules, for new passwords.
  static String? newPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    for (final rule in passwordRules) {
      if (!rule.isMet(v)) return rule.error;
    }
    return null;
  }

  /// Presence only, for logging in.
  static String? loginPassword(String? value) =>
      (value == null || value.isEmpty) ? 'Password is required' : null;

  static String? Function(String?) confirmPassword(String Function() original) =>
      (value) => (value ?? '').isEmpty
          ? 'Please confirm your password'
          : value != original()
              ? 'Passwords do not match'
              : null;

  static String? otp(String? value) =>
      _otpPattern.hasMatch(value?.trim() ?? '') ? null : 'Enter the 6-digit code';

  /// Shown as a live checklist under the password field.
  static final List<PasswordRule> passwordRules = [
    PasswordRule('At least 8 characters', 'Password must be at least 8 characters', (v) => v.length >= 8),
    PasswordRule('At most 72 characters', 'Password must be at most 72 characters', (v) => v.length <= 72),
    PasswordRule('An uppercase letter', 'Password must contain an uppercase letter', (v) => v.contains(RegExp('[A-Z]'))),
    PasswordRule('A lowercase letter', 'Password must contain a lowercase letter', (v) => v.contains(RegExp('[a-z]'))),
    PasswordRule('A number', 'Password must contain a number', (v) => v.contains(RegExp('[0-9]'))),
  ];
}

class PasswordRule {
  const PasswordRule(this.label, this.error, this.isMet);

  final String label;
  final String error;
  final bool Function(String value) isMet;
}
