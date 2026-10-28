import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/listing_models.dart';

/// Cover image with a placeholder when there is none.
class ListingCover extends StatelessWidget {
  const ListingCover({super.key, required this.url, required this.isFunding, this.height = 160});

  final String? url;
  final bool isFunding;
  final double height;

  @override
  Widget build(BuildContext context) {
    // no photo yet: a soft brand gradient (purple for funding, teal for sale) with the type icon
    final placeholder = Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isFunding ? [AppTheme.brand, AppTheme.brandSecondary] : [AppTheme.accentText, AppTheme.brand],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        isFunding ? Icons.trending_up : Icons.sell_outlined,
        size: height / 3,
        color: Colors.white.withValues(alpha: 0.9),
      ),
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

/// Grey outline of a listing card, shown while the listings load.
class ListingCardSkeleton extends StatelessWidget {
  const ListingCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final block = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: block, borderRadius: BorderRadius.circular(Radii.sm)),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 120, color: block),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    bar(90, 22),
                    const SizedBox(width: Gaps.sm),
                    bar(60, 22),
                  ],
                ),
                const SizedBox(height: Gaps.md),
                bar(220, 16),
                const SizedBox(height: Gaps.sm),
                bar(160, 12),
                const SizedBox(height: Gaps.md),
                bar(110, 18),
              ],
            ),
          ),
        ],
      ),
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
    final status = StatusColors.of(context);
    final statusColor = switch (listing.status) {
      'published' => status.success,
      'closed' => colors.outline,
      'suspended' => status.danger,
      _ => status.warning,
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
            color: listing.reviewStatus == 'approved' ? status.success : status.info,
            icon: listing.reviewStatus == 'approved' ? Icons.verified_outlined : Icons.hourglass_top,
          ),
      ],
    );
  }
}

/// Horizontal strip of project photos (hardware, screenshots). Tapping a photo opens it full screen.
/// With [onAdd] and [onRemove] the owner can manage them; [onAdd] is hidden once the limit is reached.
class PhotoStrip extends StatelessWidget {
  const PhotoStrip({super.key, required this.images, this.onAdd, this.onRemove});

  final List<ImageProvider> images;
  final VoidCallback? onAdd;
  final void Function(int index)? onRemove;

  static const double _size = 96;

  void _open(BuildContext context, ImageProvider image) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: InteractiveViewer(
        child: Image(image: image, fit: BoxFit.contain),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final canAdd = onAdd != null && images.length < maxListingPhotos;
    return SizedBox(
      height: _size,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < images.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () => _open(context, images[i]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image(
                        image: images[i],
                        width: _size,
                        height: _size,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: _size,
                          height: _size,
                          color: colors.surfaceContainerHighest,
                          child: Icon(Icons.broken_image_outlined, color: colors.outline),
                        ),
                      ),
                    ),
                  ),
                  if (onRemove != null)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: IconButton.filledTonal(
                        tooltip: 'Remove photo',
                        visualDensity: VisualDensity.compact,
                        iconSize: 16,
                        onPressed: () => onRemove!(i),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                ],
              ),
            ),
          if (canAdd)
            InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, color: colors.primary),
                    const SizedBox(height: 4),
                    Text('Add photo', style: TextStyle(color: colors.primary, fontSize: 12)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
