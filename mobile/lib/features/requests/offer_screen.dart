import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';

/// One negotiation: the live terms on top, every version below on the offer timeline, and
/// Accept / Counter / Decline. Countering opens a sheet with amount, equity and expiry.
// TODO: wire in Week 11 (bidding): GET /offers/:id with versions; POST counter / accept / decline.
class OfferScreen extends StatefulWidget {
  const OfferScreen({super.key, required this.offerId});

  final String offerId;

  @override
  State<OfferScreen> createState() => _OfferScreenState();
}

class _OfferScreenState extends State<OfferScreen> {
  final _history = <TimelineEntry>[
    const TimelineEntry(
      title: 'Offer from Ali Khan',
      time: '2 Nov, 10:15',
      amount: 'PKR 1,000,000',
      detail: '10% equity · expired after 7 days',
      icon: Icons.local_offer_outlined,
      status: AppStatus.countered,
      role: ToneRole.countered,
      subtitle: 'Happy to move fast if the pilot results hold up.',
    ),
    const TimelineEntry(
      title: 'Your counteroffer',
      time: '3 Nov, 18:40',
      amount: 'PKR 1,400,000',
      detail: '8% equity',
      icon: Icons.swap_horiz,
      status: AppStatus.countered,
      role: ToneRole.countered,
    ),
    const TimelineEntry(
      title: 'Counteroffer from Ali Khan',
      time: '4 Nov, 09:05',
      amount: 'PKR 1,250,000',
      detail: '9% equity · expires in 5 days',
      icon: Icons.swap_horiz,
      status: AppStatus.pending,
      role: ToneRole.pending,
      isCurrent: true,
    ),
  ];

  Future<void> _counter() async {
    final entry = await showAppBottomSheet<TimelineEntry>(
      context,
      title: 'Make a counteroffer',
      subtitle: 'The other side can accept, counter or decline it before it expires.',
      builder: (context) => const _CounterSheet(),
    );
    if (entry == null || !mounted) return;
    setState(() {
      final last = _history.removeLast();
      _history
        ..add(
          TimelineEntry(
            title: last.title,
            time: last.time,
            amount: last.amount,
            detail: last.detail,
            icon: last.icon,
            status: AppStatus.countered,
            role: ToneRole.countered,
          ),
        )
        ..add(entry);
    });
    showAppToast(context, 'Counteroffer sent (sample)', role: ToneRole.approved);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = AppColors.of(context);
    final current = _history.last;

    return Scaffold(
      appBar: const AppAppBar(title: 'Offer', subtitle: 'Smart irrigation kit'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, Gaps.xxl),
        children: [
          AppCard(
            variant: AppCardVariant.tinted,
            role: ToneRole.funding,
            padding: const EdgeInsets.all(Gaps.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('CURRENT TERMS', style: theme.textTheme.overline.copyWith(color: app.funding.fg)),
                    const Spacer(),
                    if (current.status != null) StatusChip.status(current.status!),
                  ],
                ),
                const SizedBox(height: Gaps.sm),
                Text(current.amount ?? '', style: theme.textTheme.numeric(size: 32)),
                const SizedBox(height: Gaps.xs),
                Text(current.detail ?? '', style: theme.textTheme.bodyMedium),
                const SizedBox(height: Gaps.lg),
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: IconSizes.sm, color: app.pending.fg),
                    const SizedBox(width: Gaps.xs),
                    Text('Respond before it expires', style: theme.textTheme.labelMedium),
                  ],
                ),
              ],
            ),
          ),
          const SectionHeader('Version history', subtitle: 'Oldest first. Every change is kept.'),
          Timeline(entries: _history),
          const DisclaimerBanner(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: app.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gaps.lg, Gaps.md, Gaps.lg, Gaps.md),
            child: Row(
              children: [
                IconButton.outlined(
                  tooltip: 'Decline',
                  onPressed: () async {
                    final sure = await confirmAction(
                      context,
                      title: 'Decline this offer?',
                      message: 'The negotiation ends. You can still receive new offers on the listing.',
                      confirmLabel: 'Decline',
                      destructive: true,
                      icon: Icons.block,
                    );
                    if (sure && context.mounted) showAppToast(context, 'Declining arrives in Week 11');
                  },
                  icon: const Icon(Icons.close),
                ),
                const SizedBox(width: Gaps.sm),
                Expanded(
                  child: AppButton.secondary(label: 'Counter', icon: Icons.swap_horiz, onPressed: _counter),
                ),
                const SizedBox(width: Gaps.sm),
                Expanded(
                  child: AppButton(
                    label: 'Accept',
                    icon: Icons.handshake_outlined,
                    onPressed: () => showAppToast(context, 'Accepting arrives in Week 11', role: ToneRole.pending),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CounterSheet extends StatefulWidget {
  const _CounterSheet();

  @override
  State<_CounterSheet> createState() => _CounterSheetState();
}

class _CounterSheetState extends State<_CounterSheet> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _equity = TextEditingController();
  final _note = TextEditingController();
  int _days = 7;

  @override
  void dispose() {
    for (final c in [_amount, _equity, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  String _grouped(String digits) => digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  void _send() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      TimelineEntry(
        title: 'Your counteroffer',
        time: 'Just now',
        amount: 'PKR ${_grouped(_amount.text.trim())}',
        detail: '${_equity.text.trim()}% equity · expires in $_days days',
        subtitle: _note.text.trim().isEmpty ? null : _note.text.trim(),
        icon: Icons.swap_horiz,
        status: AppStatus.pending,
        role: ToneRole.pending,
        isCurrent: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _amount,
            label: 'Amount (PKR)',
            icon: Icons.payments_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) => (num.tryParse(v ?? '') ?? 0) > 0 ? null : 'Enter an amount',
          ),
          const SizedBox(height: Gaps.lg),
          AppTextField(
            controller: _equity,
            label: 'Equity (%)',
            icon: Icons.pie_chart_outline,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            validator: (v) {
              final n = num.tryParse(v ?? '');
              return n == null || n <= 0 || n > 100 ? 'Enter a percentage between 0 and 100' : null;
            },
          ),
          const SizedBox(height: Gaps.lg),
          AppTextField(controller: _note, label: 'Message (optional)', maxLines: 3),
          const SizedBox(height: Gaps.lg),
          Text('Expires in', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: Gaps.sm),
          Wrap(
            spacing: Gaps.sm,
            children: [
              for (final d in const [3, 7, 14])
                ChoiceChip(label: Text('$d days'), selected: _days == d, onSelected: (_) => setState(() => _days = d)),
            ],
          ),
          const SizedBox(height: Gaps.xl),
          AppButton(label: 'Send counteroffer', icon: Icons.send, onPressed: _send),
        ],
      ),
    );
  }
}
