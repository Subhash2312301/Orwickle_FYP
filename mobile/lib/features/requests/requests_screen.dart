import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/motion/entrance.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../auth/session/session_controller.dart';
import '../listings/widgets/listing_widgets.dart';
import '../shell/coming_soon.dart';

/// One access request in the list (mock).
class MockRequest {
  const MockRequest(this.id, this.person, this.role, this.listing, this.isFunding, this.status, this.time, this.note);

  final String id;
  final String person;
  final String role;
  final String listing;
  final bool isFunding;
  final AppStatus status;
  final String time;
  final String note;
}

/// One negotiation in the list (mock).
class MockOffer {
  const MockOffer(this.id, this.person, this.listing, this.isFunding, this.amount, this.detail, this.status);

  final String id;
  final String person;
  final String listing;
  final bool isFunding;
  final String amount;
  final String detail;
  final AppStatus status;
}

// TODO: wire in Week 10 (access requests): GET /access-requests (incoming for owners, mine for others).
const _requests = [
  MockRequest(
    'r1',
    'Ali Khan',
    'Investor',
    'Smart irrigation kit',
    true,
    AppStatus.pending,
    '2 h ago',
    'Interested in the hardware costs and the pilot results.',
  ),
  MockRequest(
    'r2',
    'Nadia Farooq',
    'Investor',
    'Smart irrigation kit',
    true,
    AppStatus.approved,
    'Yesterday',
    'Angel investor, AgriTech focus.',
  ),
  MockRequest(
    'r3',
    'Pixel Agency',
    'Buyer',
    'Clinic booking system',
    false,
    AppStatus.rejected,
    '3 days ago',
    'Would like to resell the system to clinics.',
  ),
];

// TODO: wire in Week 11 (bidding): GET /offers with the latest version of each negotiation.
const _offers = [
  MockOffer(
    'o1',
    'Ali Khan',
    'Smart irrigation kit',
    true,
    'PKR 1,400,000',
    '8% equity · expires in 5 days',
    AppStatus.countered,
  ),
  MockOffer(
    'o2',
    'Pixel Agency',
    'Clinic booking system',
    false,
    'PKR 280,000',
    'Full source + 1 month support',
    AppStatus.pending,
  ),
  MockOffer('o3', 'Nadia Farooq', 'Smart irrigation kit', true, 'PKR 900,000', '6% equity', AppStatus.expired),
];

/// Requests & offers: access requests (Pending / Approved / Rejected) and negotiations.
/// Owners see incoming requests with Approve / Reject; investors and buyers see their own.
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  bool _showOffers = false;
  AppStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final owner = context.select<SessionController, bool>((s) => s.user?.role == 'owner');
    final requests = _filter == null ? _requests : _requests.where((r) => r.status == _filter).toList();

    return Scaffold(
      appBar: const AppAppBar(title: 'Requests', large: true, actions: [ShellActions()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.xxl),
        children: [
          SegmentedToggle<bool>(
            value: _showOffers,
            onChanged: (v) => setState(() => _showOffers = v),
            segments: const [
              ToggleSegment(value: false, label: 'Access', icon: Icons.lock_open_outlined),
              ToggleSegment(value: true, label: 'Offers', icon: Icons.local_offer_outlined),
            ],
          ),
          const SizedBox(height: Gaps.md),
          const AppBanner(
            icon: Icons.science_outlined,
            role: ToneRole.neutral,
            message: 'Preview with sample data. Requests and offers are connected in the next phases.',
          ),
          if (!_showOffers) ...[
            Wrap(
              spacing: Gaps.sm,
              runSpacing: Gaps.sm,
              children: [
                for (final s in [null, AppStatus.pending, AppStatus.approved, AppStatus.rejected])
                  CategoryChip(
                    label: s?.label ?? 'All',
                    selected: _filter == s,
                    onSelected: (_) => setState(() => _filter = s),
                  ),
              ],
            ),
            SectionHeader(owner ? 'Incoming requests' : 'Your requests'),
            if (requests.isEmpty)
              const EmptyState(
                icon: Icons.inbox_outlined,
                role: ToneRole.neutral,
                title: 'No requests',
                message: 'Nothing with this status.',
              ),
            for (final (i, r) in requests.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: Gaps.md),
                child: _RequestTile(request: r, owner: owner).entrance(context, index: i),
              ),
          ] else ...[
            const SectionHeader('Negotiations', subtitle: 'Every version is kept, with its expiry.'),
            for (final (i, o) in _offers.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: Gaps.md),
                child: _OfferTile(offer: o).entrance(context, index: i),
              ),
          ],
          const DisclaimerBanner(),
        ],
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request, required this.owner});

  final MockRequest request;
  final bool owner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = request;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OwnerChip(name: owner ? r.person : r.listing, subtitle: owner ? r.role : 'Project'),
              ),
              StatusChip.status(r.status),
            ],
          ),
          const SizedBox(height: Gaps.md),
          Row(
            children: [
              ListingTypeChip(isFunding: r.isFunding, short: true),
              const SizedBox(width: Gaps.sm),
              Expanded(
                child: Text(
                  owner ? r.listing : 'Sent ${r.time}',
                  style: theme.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gaps.sm),
          Text('“${r.note}”', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.of(context).textMuted)),
          if (owner && r.status == AppStatus.pending) ...[
            const SizedBox(height: Gaps.md),
            Row(
              children: [
                Expanded(
                  child: AppButton.secondary(
                    label: 'Reject',
                    size: AppButtonSize.compact,
                    onPressed: () => showAppToast(context, 'Rejecting requests arrives in Week 10'),
                  ),
                ),
                const SizedBox(width: Gaps.md),
                Expanded(
                  child: AppButton(
                    label: 'Approve',
                    size: AppButtonSize.compact,
                    onPressed: () => showAppToast(context, 'Approving requests arrives in Week 10'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OfferTile extends StatelessWidget {
  const _OfferTile({required this.offer});

  final MockOffer offer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final o = offer;
    return AppCard(
      onTap: () => context.push(Routes.offer(o.id)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ListingTypeChip(isFunding: o.isFunding, short: true),
                    const SizedBox(width: Gaps.sm),
                    StatusChip.status(o.status),
                  ],
                ),
                const SizedBox(height: Gaps.sm),
                Text(o.listing, style: theme.textTheme.titleSmall),
                Text('with ${o.person}', style: theme.textTheme.bodySmall),
                const SizedBox(height: Gaps.sm),
                Text(o.amount, style: theme.textTheme.numeric(size: 18)),
                Text(o.detail, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
