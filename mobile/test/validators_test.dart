import 'package:flutter_test/flutter_test.dart';
import 'package:orwickle/core/validation/validators.dart';

void main() {
  test('email', () {
    expect(Validators.email(''), 'Email is required');
    expect(Validators.email('subhash@'), 'Enter a valid email address');
    expect(Validators.email(' subhash@example.com '), isNull);
  });

  test('new password follows the backend rules', () {
    expect(Validators.newPassword(''), 'Password is required');
    expect(Validators.newPassword('Ab1'), 'Password must be at least 8 characters');
    expect(Validators.newPassword('lowercase1'), 'Password must contain an uppercase letter');
    expect(Validators.newPassword('UPPERCASE1'), 'Password must contain a lowercase letter');
    expect(Validators.newPassword('NoNumbers'), 'Password must contain a number');
    expect(Validators.newPassword('Orbitlane42'), r'Password must contain a special character (e.g. ! @ # $)');
    expect(Validators.newPassword('A${'a' * 71}1'), 'Password must be at most 72 characters');
    expect(Validators.newPassword('Orbit#Lane42'), isNull);
  });

  test('common and personal passwords are refused', () {
    const tooCommon = 'This password is too common. Choose something harder to guess.';
    for (final weak in ['Password1!', 'P@ssw0rd1!', 'Pakistan@123', 'Qwerty123!', 'Welcome#2026']) {
      expect(Validators.newPassword(weak), tooCommon, reason: weak);
    }
    expect(Validators.newPassword('Subhash#2026', name: 'Subhash Rai'), 'Password must not contain your name or email');
    expect(
      Validators.newPassword('Orbit#al2026', name: 'Al Noor'),
      isNull,
      reason: 'parts under 3 letters are ignored',
    );
    expect(
      Validators.newPassword('Xavi#subhash1', email: 'subhash@example.com'),
      'Password must not contain your name or email',
    );
  });

  test('confirm password', () {
    final confirm = Validators.confirmPassword(() => 'Secret123');
    expect(confirm(''), 'Please confirm your password');
    expect(confirm('Secret124'), 'Passwords do not match');
    expect(confirm('Secret123'), isNull);
  });

  test('full name and OTP', () {
    expect(Validators.fullName(' A '), 'Full name must be at least 2 characters');
    expect(Validators.fullName('Subhash Rai'), isNull);
    expect(Validators.otp('12345'), 'Enter the 6-digit code');
    expect(Validators.otp('12a456'), 'Enter the 6-digit code');
    expect(Validators.otp('123456'), isNull);
  });
}
