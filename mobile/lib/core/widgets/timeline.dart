import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'chips.dart';

/// One event in a [Timeline]: an offer, a counteroffer, an acceptance, an expiry.
class TimelineEntry {
  const TimelineEntry({
    required this.title,
    required this.time,
    this.subtitle,
    this.amount,
    this.detail,
    this.role = ToneRole.info,
    this.icon = Icons.circle,
    this.status,
    this.isCurrent = false,
  });

  final String title; // "Counteroffer from Sara"
  final String time; // "2 Nov, 14:05"
  final String? subtitle;
  final String? amount; // "PKR 1,200,000"
  final String? detail; // "12% equity · expires in 2 days"
  final ToneRole role;
  final IconData icon;
  final AppStatus? status;

  /// The live version; highlighted with a coloured border.
  final bool isCurrent;
}

/// Vertical history (offer versions, request steps): a coloured node per event joined by a rail,
/// each with a small card. Oldest first; the current entry stands out.
/// Built for bidding (offers, counteroffers, version history, expiry) so it can be reused there.
class Timeline extends StatelessWidget {
  const Timeline({super.key, required this.entries});

  final List<TimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          _TimelineRow(entry: entries[i], first: i == 0, last: i == entries.length - 1, index: i),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry, required this.first, required this.last, required this.index});

  final TimelineEntry entry;
  final bool first;
  final bool last;
  final int index;

  static const double _node = 32;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = AppColors.of(context);
    final tone = entry.role.resolve(context);

    return Semantics(
      container: true,
      label: 'Version ${index + 1}${entry.isCurrent ? ', current' : ''}',
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _node,
              child: Column(
                children: [
                  Container(width: Sizes.focusRing, height: Gaps.md, color: first ? Colors.transparent : app.border),
                  Container(
                    width: _node,
                    height: _node,
                    decoration: BoxDecoration(
                      color: tone.bg,
                      shape: BoxShape.circle,
                      border: Border.all(color: entry.isCurrent ? tone.fg : Colors.transparent, width: Sizes.focusRing),
                    ),
                    child: Icon(entry.icon, size: IconSizes.sm, color: tone.fg),
                  ),
                  Expanded(
                    child: Container(width: Sizes.focusRing, color: last ? Colors.transparent : app.border),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gaps.md),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: Gaps.xs, bottom: last ? 0 : Gaps.lg),
                child: Container(
                  padding: const EdgeInsets.all(Gaps.md + Gaps.xs),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(
                      color: entry.isCurrent ? tone.fg.withValues(alpha: 0.6) : app.border,
                      width: entry.isCurrent ? Sizes.focusRing : Sizes.hairline,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(entry.title, style: theme.textTheme.titleSmall)),
                          if (entry.status != null) StatusChip.status(entry.status!),
                        ],
                      ),
                      const SizedBox(height: Gaps.xxs),
                      Text(entry.time, style: theme.textTheme.bodySmall),
                      if (entry.amount != null) ...[
                        const SizedBox(height: Gaps.sm),
                        Text(entry.amount!, style: theme.textTheme.numeric(size: 20)),
                      ],
                      if (entry.detail != null) ...[
                        const SizedBox(height: Gaps.xxs),
                        Text(entry.detail!, style: theme.textTheme.bodyMedium?.copyWith(color: app.textMuted)),
                      ],
                      if (entry.subtitle != null) ...[
                        const SizedBox(height: Gaps.sm),
                        Text(entry.subtitle!, style: theme.textTheme.bodyMedium),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
