/// Form rules. They match the backend's rules (backend/src/modules/auth/auth.validation.js
/// and passwordPolicy.js), so most mistakes are caught before a request is sent.
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

  /// Full strength rules, for new passwords. [name] and [email] are the user's own details,
  /// which the password must not contain.
  static String? newPassword(String? value, {String? name, String? email}) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    for (final rule in passwordRules) {
      if (!rule.isMet(v)) return rule.error;
    }
    if (isCommonPassword(v)) return 'This password is too common. Choose something harder to guess.';
    if (containsPersonalInfo(v, name: name, email: email)) return 'Password must not contain your name or email';
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
    PasswordRule('A special character', 'Password must contain a special character (e.g. ! @ # \$)',
        (v) => v.contains(RegExp('[^A-Za-z0-9]'))),
  ];

  // Same list and logic as backend/src/modules/auth/passwordPolicy.js
  static const _commonWords = {
    'password', 'passwd', 'pass', 'qwerty', 'qwertyuiop', 'asdf', 'asdfgh', 'asdfghjkl', 'zxcv', 'zxcvbn',
    'zxcvbnm', 'qwer', 'qwe', 'abc', 'abcd', 'abcde', 'abcdef', 'abcdefg', 'abcdefgh', 'admin', 'administrator',
    'welcome', 'letmein', 'iloveyou', 'love', 'test', 'testing', 'user', 'login', 'secret', 'master', 'monkey',
    'dragon', 'football', 'cricket', 'baseball', 'soccer', 'sunshine', 'princess', 'superman', 'batman',
    'shadow', 'freedom', 'whatever', 'trustno', 'hello', 'hellohello', 'changeme', 'default', 'guest',
    'pakistan', 'karachi', 'lahore', 'islamabad', 'allah', 'bismillah', 'mashallah', 'india', 'orwickle',
    'szabist', 'student', 'computer', 'internet', 'google', 'facebook', 'instagram', 'samsung', 'apple',
    'iphone', 'android', 'summer', 'winter', 'spring', 'autumn', 'money', 'qazwsx', 'aaa', 'aaaa',
  };
  static const _leet = {'0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't', '8': 'b', '@': 'a', r'$': 's'};

  /// "P@ssw0rd1!" and "Pakistan@123" count as common: swaps between letters are undone,
  /// then digits and symbols are dropped, and the remaining word is looked up.
  static bool isCommonPassword(String password) {
    final base = password
        .toLowerCase()
        .replaceAllMapped(RegExp(r'(?<=[a-z])[0134578@$](?=[a-z])'), (m) => _leet[m[0]]!)
        .replaceAll(RegExp('[^a-z]'), '');
    return base.length < 3 || _commonWords.contains(base);
  }

  static bool containsPersonalInfo(String password, {String? name, String? email}) {
    final lower = password.toLowerCase();
    final parts = [
      ...(name ?? '').toLowerCase().split(RegExp(r'\s+')),
      (email ?? '').toLowerCase().split('@').first,
    ].where((p) => p.length >= 3);
    return parts.any(lower.contains);
  }
}

class PasswordRule {
  const PasswordRule(this.label, this.error, this.isMet);

  final String label;
  final String error;
  final bool Function(String value) isMet;
}
