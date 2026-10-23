class Category {
  const Category({required this.id, required this.name});

  factory Category.fromJson(Map<String, dynamic> json) =>
      Category(id: json['id'] as String, name: json['name'] as String);

  final String id;
  final String name;
}

/// The logged-in user's profile from GET /api/profile/me.
/// [details] holds the role-specific fields exactly as the API names them.
class MyProfile {
  const MyProfile({
    required this.role,
    required this.email,
    required this.fullName,
    this.avatarUrl,
    this.headline,
    this.bio,
    this.city,
    this.linkedinUrl,
    this.websiteUrl,
    required this.completed,
    required this.details,
  });

  factory MyProfile.fromJson(Map<String, dynamic> json) => MyProfile(
    role: json['role'] as String,
    email: json['email'] as String,
    fullName: json['fullName'] as String,
    avatarUrl: json['avatarUrl'] as String?,
    headline: json['headline'] as String?,
    bio: json['bio'] as String?,
    city: json['city'] as String?,
    linkedinUrl: json['linkedinUrl'] as String?,
    websiteUrl: json['websiteUrl'] as String?,
    completed: json['completed'] as bool? ?? false,
    details: json['details'] is Map ? Map<String, dynamic>.from(json['details'] as Map) : const {},
  );

  final String role;
  final String email;
  final String fullName;
  final String? avatarUrl; // short-lived link; null when there is no photo
  final String? headline;
  final String? bio;
  final String? city;
  final String? linkedinUrl;
  final String? websiteUrl;
  final bool completed;
  final Map<String, dynamic> details;

  String? detailText(String key) => details[key] as String?;
  num? detailNumber(String key) => details[key] as num?;

  List<String> get skills => [for (final s in (details['skills'] as List? ?? const [])) '$s'];

  Set<String> get interestIds => {
    for (final i in (details['interests'] as List? ?? const [])) (i as Map)['id'] as String,
  };
}

/// Labels for the API's enum values.
const investorTypes = {
  'individual': 'Individual investor',
  'angel': 'Angel investor',
  'firm': 'Investment firm / VC',
  'other': 'Other',
};

const buyerTypes = {
  'individual': 'Individual',
  'small_business': 'Small business',
  'agency': 'Software agency',
  'other': 'Other',
};

const currencies = ['PKR', 'USD'];
