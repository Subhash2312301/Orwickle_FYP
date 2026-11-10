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

  test('names, city, headline, designation and organization refuse numbers and symbols', () {
    const nameRule = "Full name can only contain letters, spaces and . ' -";
    expect(Validators.fullName('Subhash123'), nameRule);
    expect(Validators.fullName('@@##'), nameRule);
    expect(Validators.fullName("Ali O'Brien-Khan"), isNull);

    final city = Validators.personName('City', max: 80);
    expect(city('Karachi1'), "City can only contain letters, spaces and . ' -");
    expect(city('Rahim Yar Khan'), isNull);

    final designation = Validators.titleText('Professional designation', max: 100);
    const titleRule = "Professional designation can only contain letters, spaces and . , & - / ( ) '";
    for (final bad in ['12345', '@@##', 'CEO!!', 'Manager 2']) {
      expect(designation(bad), titleRule, reason: bad);
    }
    for (final good in ['Managing Partner', 'Co-Founder & CEO', 'VP (Investments)', 'Angel Investor']) {
      expect(designation(good), isNull, reason: good);
    }
    expect(Validators.titleText('Headline', max: 150)('Final-year CS student, building EdTech apps'), isNull);

    final organization = Validators.organization('Organization or company', max: 150);
    expect(organization('500 Startups'), isNull);
    expect(organization('Karachi Seed Ventures'), isNull);
    expect(organization('12345'), "Organization or company can only contain letters, numbers, spaces and . , & - / ( ) '");
    expect(organization('Ventures@#'), "Organization or company can only contain letters, numbers, spaces and . , & - / ( ) '");
  });
}
