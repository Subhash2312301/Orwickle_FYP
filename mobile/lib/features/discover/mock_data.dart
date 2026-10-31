import '../listings/data/listing_models.dart';

// UI scaffolds for the next phases run on this mock data. Nothing here calls the backend.
// TODO: wire in Week 9 (discovery): replace with GET /listings?type=&category=&q=&page=.

const mockCategories = ['FinTech', 'EdTech', 'HealthTech', 'AgriTech', 'E-commerce', 'AI / ML'];

Listing _l(
  String id,
  bool funding,
  String category,
  String title,
  String description,
  num amount,
  String stage,
  String owner,
) => Listing(
  id: 'mock-$id',
  listingType: funding ? 'funding' : 'sale',
  categoryId: category,
  categoryName: category,
  title: title,
  shortDescription: description,
  techStack: const [],
  projectStage: stage,
  askingAmount: amount,
  currency: 'PKR',
  coverUrl: null,
  status: 'published',
  reviewStatus: 'approved',
  ownerName: owner,
  isSample: true,
);

final mockListings = [
  _l(
    '1',
    true,
    'AgriTech',
    'Smart irrigation kit',
    'Soil sensors and a mobile app that water crops only when needed.',
    1500000,
    'prototype',
    'Sara Ahmed',
  ),
  _l(
    '2',
    true,
    'EdTech',
    'AI tutor for O-levels',
    'Personalised practice and feedback for maths and physics students.',
    2000000,
    'mvp',
    'Hamza Khan',
  ),
  _l(
    '3',
    false,
    'HealthTech',
    'Clinic booking system',
    'Appointments, reminders and patient records for small clinics.',
    300000,
    'launched',
    'Ayesha Malik',
  ),
  _l(
    '4',
    true,
    'FinTech',
    'Campus wallet',
    'Cashless payments for university cafeterias and print shops.',
    800000,
    'mvp',
    'Bilal Raza',
  ),
  _l(
    '5',
    false,
    'E-commerce',
    'Thrift store app',
    'Buy and sell second-hand clothes with in-app delivery tracking.',
    450000,
    'launched',
    'Zainab Ali',
  ),
  _l(
    '6',
    false,
    'AI / ML',
    'Urdu OCR engine',
    'Reads printed Urdu text from photos with 94% accuracy.',
    900000,
    'prototype',
    'Usman Tariq',
  ),
  _l(
    '7',
    true,
    'HealthTech',
    'Blood donor network',
    'Matches donors and hospitals by blood group and distance.',
    1200000,
    'idea',
    'Maryam Shah',
  ),
  _l(
    '8',
    false,
    'EdTech',
    'Quiz builder for teachers',
    'Create, share and auto-mark quizzes; exports results to Excel.',
    250000,
    'launched',
    'Ali Hassan',
  ),
  _l(
    '9',
    true,
    'E-commerce',
    'Local grocer marketplace',
    'Neighbourhood shops online with same-day delivery.',
    3500000,
    'mvp',
    'Fatima Noor',
  ),
  _l(
    '10',
    false,
    'FinTech',
    'Expense tracker for SMEs',
    'Receipts by photo, monthly reports and tax summaries.',
    600000,
    'launched',
    'Daniyal Akram',
  ),
];

/// A fake paged search, so the list, skeletons and "load more" behave like the real thing will.
Future<List<Listing>> mockSearch({
  required bool funding,
  String query = '',
  Set<String> categories = const {},
  int page = 0,
  int pageSize = 4,
}) async {
  await Future<void>.delayed(const Duration(milliseconds: 600));
  final q = query.trim().toLowerCase();
  final matches = mockListings
      .where((l) => l.isFunding == funding)
      .where((l) => categories.isEmpty || categories.contains(l.categoryName))
      .where((l) => q.isEmpty || l.title.toLowerCase().contains(q) || l.shortDescription.toLowerCase().contains(q))
      .toList();
  return matches.skip(page * pageSize).take(pageSize).toList();
}
