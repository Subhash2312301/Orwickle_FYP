import 'package:flutter/material.dart';

import '../data/listing_models.dart';

/// Cover image with a placeholder when there is none.
class ListingCover extends StatelessWidget {
  const ListingCover({super.key, required this.url, required this.isFunding, this.height = 160});

  final String? url;
  final bool isFunding;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = Container(
      height: height,
      color: colors.primaryContainer,
      alignment: Alignment.center,
      child: Icon(isFunding ? Icons.trending_up : Icons.sell_outlined, size: height / 3, color: colors.primary),
    );
    if (url == null) return placeholder;
    return Image.network(
      url!,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}

/// Small coloured label: listing type, status, review status.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Type, status and (when relevant) review chips for one listing.
class ListingChips extends StatelessWidget {
  const ListingChips(this.listing, {super.key});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = switch (listing.status) {
      'published' => Colors.green.shade700,
      'closed' => colors.outline,
      'suspended' => colors.error,
      _ => Colors.orange.shade800,
    };
    final review = reviewLabels[listing.reviewStatus];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (listing.isSample) StatusChip('Sample', color: colors.outline, icon: Icons.science_outlined),
        StatusChip(
          listingTypeLabels[listing.listingType]!,
          color: colors.primary,
          icon: listing.isFunding ? Icons.trending_up : Icons.sell_outlined,
        ),
        StatusChip(statusLabels[listing.status] ?? listing.status, color: statusColor),
        if (review != null && listing.status == 'published')
          StatusChip(
            review,
            color: listing.reviewStatus == 'approved' ? Colors.green.shade700 : colors.tertiary,
            icon: listing.reviewStatus == 'approved' ? Icons.verified_outlined : Icons.hourglass_top,
          ),
      ],
    );
  }
}
