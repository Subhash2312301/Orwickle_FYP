/// Public preview of a listing (anyone logged in may see it once published).
class Listing {
  const Listing({
    required this.id,
    required this.listingType,
    required this.categoryId,
    required this.categoryName,
    required this.title,
    required this.shortDescription,
    required this.techStack,
    required this.projectStage,
    required this.askingAmount,
    required this.currency,
    required this.coverUrl,
    required this.status,
    required this.reviewStatus,
    required this.ownerName,
  });

  factory Listing.fromJson(Map<String, dynamic> j) => Listing(
    id: j['id'] as String,
    listingType: j['listingType'] as String,
    categoryId: (j['category'] as Map)['id'] as String,
    categoryName: (j['category'] as Map)['name'] as String,
    title: j['title'] as String,
    shortDescription: j['shortDescription'] as String,
    techStack: [for (final t in j['techStack'] as List? ?? const []) '$t'],
    projectStage: j['projectStage'] as String,
    askingAmount: j['askingAmount'] as num?,
    currency: j['currency'] as String? ?? 'PKR',
    coverUrl: j['coverUrl'] as String?,
    status: j['status'] as String,
    reviewStatus: j['reviewStatus'] as String,
    ownerName: (j['owner'] as Map?)?['fullName'] as String? ?? '',
  );

  final String id;
  final String listingType; // funding | sale
  final String categoryId;
  final String categoryName;
  final String title;
  final String shortDescription;
  final List<String> techStack;
  final String projectStage;
  final num? askingAmount;
  final String currency;
  final String? coverUrl;
  final String status; // draft | published | closed | suspended
  final String reviewStatus; // unreviewed | pending | approved | rejected | needs_evidence
  final String ownerName;

  bool get isFunding => listingType == 'funding';
}

/// Confidential details — returned only to the owner (and, later, to approved requesters).
class ListingConfidential {
  const ListingConfidential(this.values);

  factory ListingConfidential.fromJson(Map<String, dynamic>? j) =>
      ListingConfidential(j == null ? const {} : Map<String, dynamic>.from(j));

  final Map<String, dynamic> values;

  String? text(String key) => values[key] as String?;
  num? get equityOfferedPercent => values['equityOfferedPercent'] as num?;
}

class ListingDetail {
  const ListingDetail(this.listing, this.confidential);

  factory ListingDetail.fromJson(Map<String, dynamic> j) => ListingDetail(
    Listing.fromJson(Map<String, dynamic>.from(j['listing'] as Map)),
    j['confidential'] is Map ? ListingConfidential.fromJson(Map<String, dynamic>.from(j['confidential'] as Map)) : null,
  );

  final Listing listing;
  final ListingConfidential? confidential;
}

// ---------- labels ----------

const listingTypeLabels = {'funding': 'Seeking Funding', 'sale': 'Available for Purchase'};

const projectStages = {
  'idea': 'Idea',
  'prototype': 'Prototype',
  'mvp': 'MVP (working product)',
  'launched': 'Launched',
};

const statusLabels = {'draft': 'Draft', 'published': 'Published', 'closed': 'Closed', 'suspended': 'Suspended'};

const reviewLabels = {
  'pending': 'Awaiting review',
  'approved': 'Approved',
  'rejected': 'Rejected',
  'needs_evidence': 'More evidence needed',
};

/// Confidential fields in display order: API key → label.
const confidentialLabels = {
  'fullDescription': 'Full description',
  'problemStatement': 'Problem statement',
  'solutionDetails': 'Solution details',
  'businessModel': 'Business model',
  'traction': 'Traction',
  'financialSummary': 'Financial summary',
  'roadmap': 'Roadmap',
  'teamDetails': 'Team',
  'ipOwnershipNotes': 'Ownership notes',
  'transferDetails': 'What the buyer receives',
};

/// 1500000 → "PKR 1,500,000"
String formatAmount(num? amount, String currency) {
  if (amount == null) return '—';
  final digits = amount.round().toString();
  final grouped = digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '$currency $grouped';
}
