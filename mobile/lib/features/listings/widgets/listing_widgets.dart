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
