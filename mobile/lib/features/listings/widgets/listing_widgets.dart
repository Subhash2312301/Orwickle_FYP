import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/chips.dart';
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
          colors: isFunding ? [Palette.amber500, Palette.amber700] : [Palette.teal500, Palette.teal700],
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

/// Type and status chips for one listing.
class ListingChips extends StatelessWidget {
  const ListingChips(this.listing, {super.key});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Gaps.sm - Gaps.xxs,
      runSpacing: Gaps.sm - Gaps.xxs,
      children: [
        if (listing.isSample) const StatusChip('Sample', icon: Icons.science_outlined),
        ListingTypeChip(isFunding: listing.isFunding),
        StatusChip.status(listingStatus(listing)),
      ],
    );
  }
}

/// The one status an owner needs to see: draft, in review, live, closed, suspended,
/// or rejected / more info (shown on the draft it went back to).
AppStatus listingStatus(Listing l) => switch ((l.status, l.reviewStatus)) {
  ('published', 'approved') => AppStatus.live,
  ('published', _) => AppStatus.inReview,
  ('closed', _) => AppStatus.closed,
  ('suspended', _) => AppStatus.suspended,
  (_, 'rejected') => AppStatus.rejected,
  (_, 'needs_evidence') => AppStatus.needsInfo,
  _ => AppStatus.draft,
};

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
