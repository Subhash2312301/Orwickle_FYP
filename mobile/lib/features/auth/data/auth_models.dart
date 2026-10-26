/// The three roles a user can sign up as. Admins are created by the team, not through the app.
enum UserRole {
  owner('Project Owner', 'List your project for funding or sale'),
  investor('Investor', 'Discover startups seeking funding'),
  buyer('Buyer', 'Buy ready-made projects');

  const UserRole(this.label, this.description);

  final String label;
  final String description;

  static UserRole? fromName(String? name) => UserRole.values.where((r) => r.name == name).firstOrNull;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    required this.fullName,
    required this.emailVerified,
    this.profileCompleted = false,
    this.approvalStatus = 'unreviewed',
    this.approvalNote,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    email: json['email'] as String,
    role: json['role'] as String,
    fullName: json['fullName'] as String,
    emailVerified: json['emailVerified'] as bool? ?? false,
    profileCompleted: json['profileCompleted'] as bool? ?? false,
    approvalStatus: json['approvalStatus'] as String? ?? 'unreviewed',
    approvalNote: json['approvalNote'] as String?,
  );

  final String id;
  final String email;
  final String role; // owner / investor / buyer / admin
  final String fullName;
  final bool emailVerified;

  /// False until the first complete profile is saved; the app then shows profile setup.
  final bool profileCompleted;

  /// Admin approval of the account: unreviewed | pending | approved | rejected | needs_evidence.
  final String approvalStatus;

  /// The admin's reason when the account was rejected or more information is needed.
  final String? approvalNote;

  bool get isApproved => approvalStatus == 'approved';

  AppUser copyWith({String? fullName, bool? profileCompleted, String? approvalStatus, String? approvalNote}) => AppUser(
    id: id,
    email: email,
    role: role,
    fullName: fullName ?? this.fullName,
    emailVerified: emailVerified,
    profileCompleted: profileCompleted ?? this.profileCompleted,
    approvalStatus: approvalStatus ?? this.approvalStatus,
    approvalNote: approvalStatus == null ? this.approvalNote : approvalNote,
  );

  String get roleLabel => UserRole.fromName(role)?.label ?? 'Administrator';

  /// "Subhash Rai" → "SR"; shown when there is no profile photo.
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }
}

/// Returned by login, verify-email and refresh.
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    expiresIn: Duration(seconds: (json['expiresIn'] as num).toInt()),
    user: AppUser.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
  );

  final String accessToken;
  final String refreshToken;
  final Duration expiresIn;
  final AppUser user;
}

enum OtpPurpose {
  emailVerify('email_verify'),
  passwordReset('password_reset');

  const OtpPurpose(this.apiValue);

  final String apiValue;
}
