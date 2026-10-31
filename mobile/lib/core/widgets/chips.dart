import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Which meaning colour a chip, banner or icon uses. Resolved against the current theme,
/// so widgets taking a [ToneRole] can still be `const`.
enum ToneRole {
  funding,
  sale,
  pending,
  approved,
  rejected,
  expired,
  countered,
  verified,
  info,
  neutral;

  Tone resolve(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return switch (this) {
      funding => c.funding,
      sale => c.sale,
      pending => c.pending,
      approved => c.approved,
      rejected => c.rejected,
      expired => c.expired,
      countered => c.countered,
      verified => c.verified,
      info => c.info,
      neutral => Tone(scheme.onSurfaceVariant, scheme.surfaceContainerHigh),
    };
  }
}

/// Statuses used across listings, access requests and offers, with their label, colour and icon.
/// Colour is never the only cue: every status also has an icon and a word.
enum AppStatus {
  draft('Draft', ToneRole.neutral, Icons.edit_note),
  inReview('In review', ToneRole.pending, Icons.hourglass_top),
  live('Live', ToneRole.approved, Icons.check_circle_outline),
  pending('Pending', ToneRole.pending, Icons.schedule),
  approved('Approved', ToneRole.approved, Icons.check_circle_outline),
  rejected('Rejected', ToneRole.rejected, Icons.cancel_outlined),
  needsInfo('More info needed', ToneRole.rejected, Icons.help_outline),
  expired('Expired', ToneRole.expired, Icons.timer_off_outlined),
  countered('Countered', ToneRole.countered, Icons.swap_horiz),
  accepted('Accepted', ToneRole.approved, Icons.handshake_outlined),
  closed('Closed', ToneRole.expired, Icons.lock_outline),
  suspended('Suspended', ToneRole.rejected, Icons.block);

  const AppStatus(this.label, this.role, this.icon);

  final String label;
  final ToneRole role;
  final IconData icon;
}

/// Small tinted pill: a status, a listing type, a "Sample" or "Coming soon" label.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.role = ToneRole.neutral, this.icon});

  /// A chip for one of the shared [AppStatus] values.
  StatusChip.status(AppStatus status, {super.key, String? label})
    : label = label ?? status.label,
      role = status.role,
      icon = status.icon;

  final String label;
  final ToneRole role;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tone = role.resolve(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gaps.sm + Gaps.xxs, vertical: Gaps.xs),
      decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: IconSizes.xs, color: tone.fg), const SizedBox(width: Gaps.xs)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: tone.fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Seeking Funding" (amber, trending up) or "For Sale" (teal, tag): the two listing types,
/// recognisable at a glance.
class ListingTypeChip extends StatelessWidget {
  const ListingTypeChip({super.key, required this.isFunding, this.short = false});

  final bool isFunding;

  /// "Funding" / "For sale" instead of the full names, for tight cards.
  final bool short;

  @override
  Widget build(BuildContext context) => StatusChip(
    isFunding ? (short ? 'Funding' : 'Seeking Funding') : (short ? 'For sale' : 'Available for Purchase'),
    role: isFunding ? ToneRole.funding : ToneRole.sale,
    icon: isFunding ? Icons.trending_up : Icons.sell_outlined,
  );
}

/// A category, either as a label ([onSelected] null) or as a selectable filter.
class CategoryChip extends StatelessWidget {
  const CategoryChip({super.key, required this.label, this.selected = false, this.onSelected, this.icon});

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (onSelected == null) {
      return StatusChip(label, icon: icon ?? Icons.category_outlined);
    }
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      avatar: icon == null || selected ? null : Icon(icon, size: IconSizes.sm),
      showCheckmark: true,
    );
  }
}

/// The user's role as a small badge. Investors share the funding colour, buyers the sale colour,
/// owners the brand cobalt, so roles and listing types read as one system.
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role, required this.label});

  /// owner | investor | buyer | admin
  final String role;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (toneRole, icon) = switch (role) {
      'owner' => (ToneRole.info, Icons.lightbulb_outline),
      'investor' => (ToneRole.funding, Icons.trending_up),
      'buyer' => (ToneRole.sale, Icons.shopping_bag_outlined),
      _ => (ToneRole.neutral, Icons.admin_panel_settings_outlined),
    };
    return StatusChip(label, role: toneRole, icon: icon);
  }
}

/// Cobalt seal for verified owners, investors and listings.
/// Reserved: verification badges arrive in FYP-II, the slot is already in the cards.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = IconSizes.sm, this.showLabel = false});

  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final tone = AppColors.of(context).verified;
    final icon = Icon(Icons.verified, size: size, color: tone.fg);
    return Semantics(
      label: 'Verified',
      child: Tooltip(
        message: 'Verified by Orwickle',
        child: showLabel ? const StatusChip('Verified', role: ToneRole.verified, icon: Icons.verified) : icon,
      ),
    );
  }
}
