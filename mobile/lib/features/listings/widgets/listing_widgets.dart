import 'package:flutter/material.dart';

import '../../../core/motion/entrance.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/listing_models.dart';

/// Cover image, or a placeholder in the listing type's colour (amber funding, teal sale)
/// with its icon. Wrapped in a Hero when [heroTag] is set, so it flies between card and detail.
class ListingCover extends StatelessWidget {
  const ListingCover({super.key, required this.url, required this.isFunding, this.height = 160, this.heroTag});

  final String? url;
  final bool isFunding;
  final double height;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final tone = AppColors.of(context).listingType(isFunding: isFunding);
    final placeholder = Container(
      height: height,
      width: double.infinity,
      color: tone.bg,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // faint orbit rings echo the logo without competing with content
          for (final factor in const [1.6, 1.0])
            Container(
              width: height * factor * 0.7,
              height: height * factor * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: tone.fg.withValues(alpha: 0.08), width: Gaps.md),
              ),
            ),
          Icon(isFunding ? Icons.trending_up : Icons.sell_outlined, size: height / 3, color: tone.fg),
        ],
      ),
    );
    final Widget image = url == null
        ? placeholder
        : Image.network(
            url!,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => placeholder,
            frameBuilder: (context, child, frame, sync) => sync || frame != null ? child : placeholder,
          );
    final cover = ExcludeSemantics(child: image);
    return heroTag == null ? cover : Hero(tag: heroTag!, child: cover);
  }
}

/// A listing in a list: cover (with type and status chips over it), category and stage, title,
/// short description, then the ask or price and the owner.
///
/// * [showStatus]: owner's own lists show draft / in review / live.
/// * [showOwner]: discovery lists show who is behind the project (with the verified slot).
class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.listing,
    required this.onTap,
    this.showStatus = false,
    this.showOwner = true,
    this.ownerVerified = false,
    this.trailing,
  });

  final Listing listing;
  final VoidCallback onTap;
  final bool showStatus;
  final bool showOwner;
  final bool ownerVerified;

  /// Top-right action on the cover, e.g. a save button in Discover.
  final Widget? trailing;

  static const double coverHeight = 148;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = AppColors.of(context);
    final l = listing;
    final tone = app.listingType(isFunding: l.isFunding);
    final stage = projectStages[l.projectStage] ?? l.projectStage;

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      semanticLabel:
          '${listingTypeLabels[l.listingType]}: ${l.title}. ${formatAmount(l.askingAmount, l.currency)}. ${l.categoryName}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ListingCover(url: l.coverUrl, isFunding: l.isFunding, height: coverHeight, heroTag: listingHeroTag(l.id)),
              Positioned(
                left: Gaps.md,
                top: Gaps.md,
                right: Gaps.md,
                child: Row(
                  children: [
                    ListingTypeChip(isFunding: l.isFunding, short: true),
                    if (l.isSample) ...[
                      const SizedBox(width: Gaps.xs + Gaps.xxs),
                      const StatusChip('Sample', icon: Icons.science_outlined),
                    ],
                    const Spacer(),
                    if (showStatus) StatusChip.status(listingStatus(l)),
                    ?trailing,
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gaps.lg, Gaps.md + Gaps.xs, Gaps.lg, Gaps.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l.categoryName.toUpperCase()}  ·  ${stage.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.overline.copyWith(color: app.textMuted),
                ),
                const SizedBox(height: Gaps.xs + Gaps.xxs),
                Text(l.title, style: theme.textTheme.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: Gaps.xs),
                Text(
                  l.shortDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(color: app.textMuted),
                ),
                const SizedBox(height: Gaps.md + Gaps.xs),
                Divider(height: Sizes.hairline, color: app.border),
                const SizedBox(height: Gaps.md),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.isFunding ? 'SEEKING' : 'PRICE',
                            style: theme.textTheme.overline.copyWith(color: tone.fg),
                          ),
                          const SizedBox(height: Gaps.xxs),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              formatAmount(l.askingAmount, l.currency),
                              style: theme.textTheme.numeric(size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showOwner && l.ownerName.isNotEmpty)
                      Flexible(
                        child: OwnerChip(name: l.ownerName, verified: ownerVerified),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small avatar and name of a listing's owner, with the verified seal when earned.
class OwnerChip extends StatelessWidget {
  const OwnerChip({super.key, required this.name, this.verified = false, this.subtitle});

  final String name;
  final bool verified;
  final String? subtitle;

  static String initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppAvatar(initials: initialsOf(name), size: 32),
        const SizedBox(width: Gaps.sm),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge),
                  ),
                  if (verified) ...[const SizedBox(width: Gaps.xs), const VerifiedBadge()],
                ],
              ),
              if (subtitle != null) Text(subtitle!, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

/// Grey outline of a [ListingCard], shown while listings load.
class ListingCardSkeleton extends StatelessWidget {
  const ListingCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(height: ListingCard.coverHeight, radius: 0),
          Padding(
            padding: EdgeInsets.all(Gaps.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 120, height: 10),
                SizedBox(height: Gaps.md),
                SkeletonBox(width: 220, height: 18),
                SizedBox(height: Gaps.md),
                SkeletonLines(lines: 2),
                SizedBox(height: Gaps.lg),
                Row(
                  children: [
                    SkeletonBox(width: 110, height: 20),
                    Spacer(),
                    SkeletonBox.circle(size: 32),
                    SizedBox(width: Gaps.sm),
                    SkeletonBox(width: 70, height: 12),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A few card skeletons in a list, shimmering.
class ListingSkeletonList extends StatelessWidget {
  const ListingSkeletonList({super.key, this.count = 3, this.padding = const EdgeInsets.all(Gaps.page)});

  final int count;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Skeleton(
    child: ListView.separated(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: Gaps.lg),
      itemBuilder: (_, _) => const ListingCardSkeleton(),
    ),
  );
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

  static const double _size = 104;

  void _open(BuildContext context, ImageProvider image) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(Gaps.md),
      clipBehavior: Clip.antiAlias,
      child: InteractiveViewer(
        child: Image(image: image, fit: BoxFit.contain),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final app = AppColors.of(context);
    final canAdd = onAdd != null && images.length < maxListingPhotos;
    return SizedBox(
      height: _size,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < images.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: Gaps.sm),
              child: Stack(
                children: [
                  Semantics(
                    button: true,
                    label: 'Photo ${i + 1}, open full screen',
                    child: GestureDetector(
                      onTap: () => _open(context, images[i]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(Radii.md),
                        child: Image(
                          image: images[i],
                          width: _size,
                          height: _size,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: _size,
                            height: _size,
                            color: colors.surfaceContainerHigh,
                            child: Icon(Icons.broken_image_outlined, color: colors.outline),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (onRemove != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        tooltip: 'Remove photo',
                        onPressed: () => onRemove!(i),
                        icon: Container(
                          padding: const EdgeInsets.all(Gaps.xs),
                          decoration: BoxDecoration(color: colors.inverseSurface, shape: BoxShape.circle),
                          child: Icon(Icons.close, size: IconSizes.sm, color: colors.onInverseSurface),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (canAdd)
            Semantics(
              button: true,
              child: InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(Radii.md),
                child: Container(
                  width: _size,
                  height: _size,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(color: app.borderStrong),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, color: colors.primary),
                      const SizedBox(height: Gaps.xs),
                      Text('Add photo', style: theme.textTheme.labelMedium?.copyWith(color: colors.primary)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
