import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/motion/entrance.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/image_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/session/session_controller.dart';
import '../../auth/widgets/form_widgets.dart';
import '../data/listing_api.dart';
import '../data/listing_models.dart';
import '../widgets/listing_widgets.dart';

/// One listing. The cover collapses into the app bar with a slight parallax.
///
/// * Owner (the API returns the confidential details only to the owner): status banners, the
///   confidential section, and the actions allowed in the listing's status.
/// * Investors and buyers: the public preview, a locked teaser of the confidential details and a
///   "Request access" button (access requests arrive in the next phase).
class ListingDetailScreen extends StatefulWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  late Future<ListingDetail> _detail = _load();
  bool _busy = false;

  static const double _headerHeight = 280;

  ListingApi get _api => context.read<ListingApi>();

  Future<ListingDetail> _load() => context.read<ListingApi>().get(widget.listingId);

  void _reload() => setState(() => _detail = _load());

  Future<void> _run(Future<ListingDetail> Function() action, String doneMessage) async {
    setState(() => _busy = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() => _detail = Future.value(updated));
      showAppToast(context, doneMessage, role: ToneRole.approved);
    } on ApiException catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message, String action, {bool destructive = false, IconData? icon}) =>
      confirmAction(
        context,
        title: title,
        message: message,
        confirmLabel: action,
        destructive: destructive,
        icon: icon,
      );

  // Changing a live listing (edit, cover, photos) hides it again until an admin re-approves it,
  // so the owner is warned first.
  Future<bool> _confirmLiveChange(Listing listing, String what) async =>
      !listing.isLive ||
      await _confirm(
        'Change a live listing?',
        'After you $what, the listing goes back to admin review and is hidden from investors and buyers '
            'until it is approved again.',
        'Continue',
        icon: Icons.visibility_off_outlined,
      );

  Future<void> _changeCover(Listing listing) async {
    if (!await _confirmLiveChange(listing, 'change the cover') || !mounted) return;
    final choice = await pickImage(context, canRemove: listing.coverUrl != null);
    if (choice == null || !mounted) return;
    await _run(
      () => switch (choice) {
        PickedImage(:final file) => _api.setCover(listing.id, file),
        RemoveImage() => _api.removeCover(listing.id),
      },
      choice is RemoveImage ? 'Cover image removed' : 'Cover image updated',
    );
  }

  Future<void> _addPhoto(Listing listing) async {
    if (!await _confirmLiveChange(listing, 'add a photo') || !mounted) return;
    final choice = await pickImage(context, canRemove: false);
    if (choice is! PickedImage || !mounted) return;
    await _run(() => _api.addPhoto(listing.id, choice.file), 'Photo added');
  }

  Future<void> _removePhoto(Listing listing, ListingPhoto photo) async {
    if (!await _confirm('Remove photo?', 'The photo is deleted from this listing.', 'Remove', destructive: true)) {
      return;
    }
    if (!await _confirmLiveChange(listing, 'remove a photo')) return;
    await _run(() => _api.removePhoto(listing.id, photo.id), 'Photo removed');
  }

  Future<void> _publish() async {
    if (await _confirm(
      'Publish listing?',
      'Investors and buyers will be able to see the public preview. Your confidential details stay private. '
          'An administrator will review the listing.',
      'Publish',
      icon: Icons.publish,
    )) {
      await _run(() => _api.changeStatus(widget.listingId, 'publish'), 'Listing published');
    }
  }

  Future<void> _unpublish() async {
    if (await _confirm('Unpublish listing?', 'It will be hidden and return to draft.', 'Unpublish')) {
      await _run(() => _api.changeStatus(widget.listingId, 'unpublish'), 'Listing moved back to draft');
    }
  }

  Future<void> _close() async {
    if (await _confirm(
      'Close listing?',
      'A closed listing can no longer be edited or published.',
      'Close',
      destructive: true,
      icon: Icons.lock_outline,
    )) {
      await _run(() => _api.changeStatus(widget.listingId, 'close'), 'Listing closed');
    }
  }

  Future<void> _delete() async {
    if (!await _confirm('Delete draft?', 'This cannot be undone.', 'Delete', destructive: true, icon: Icons.delete)) {
      return;
    }
    setState(() => _busy = true);
    try {
      await _api.delete(widget.listingId);
      if (!mounted) return;
      showInfoSnack(context, 'Draft deleted');
      context.pop();
    } on ApiException catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(Listing listing) async {
    if (!await _confirmLiveChange(listing, 'save changes') || !mounted) return;
    final saved = await context.push<bool>(Routes.editListing(widget.listingId));
    if (saved == true && mounted) _reload();
  }

  /// Secondary owner actions, in a sheet so the bottom bar keeps one clear primary action.
  Future<void> _more(Listing l) async {
    final editable = l.status == 'draft' || l.status == 'published';
    final action = await showAppBottomSheet<VoidCallback>(
      context,
      title: 'Manage listing',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (editable)
            SheetOption(
              icon: Icons.photo_camera_outlined,
              label: l.coverUrl == null ? 'Add cover image' : 'Change cover image',
              onTap: () => Navigator.pop(context, () => _changeCover(l)),
            ),
          if (l.status == 'published')
            SheetOption(
              icon: Icons.visibility_off_outlined,
              label: 'Unpublish',
              subtitle: 'Hide it and return to draft',
              onTap: () => Navigator.pop(context, _unpublish),
            ),
          if (editable)
            SheetOption(
              icon: Icons.lock_outline,
              label: 'Close listing',
              subtitle: 'It can no longer be edited or published',
              onTap: () => Navigator.pop(context, _close),
            ),
          if (l.status == 'draft')
            SheetOption(
              icon: Icons.delete_outline,
              label: 'Delete draft',
              destructive: true,
              onTap: () => Navigator.pop(context, _delete),
            ),
        ],
      ),
    );
    action?.call();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ListingDetail>(
      future: _detail,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData) {
          return const Scaffold(appBar: AppAppBar(), body: _DetailSkeleton());
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: const AppAppBar(),
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Gaps.xl),
                child: ErrorState.from(snapshot.error, fallback: 'Could not load the listing.', onRetry: _reload),
              ),
            ),
          );
        }
        final detail = snapshot.data!;
        final isOwner = detail.confidential != null;
        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () async => _reload(),
            edgeOffset: _headerHeight,
            child: CustomScrollView(
              slivers: [
                _header(detail.listing, isOwner),
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: Sizes.maxContentWidth),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.lg, Gaps.page, Gaps.xxl),
                        child: _Body(
                          detail: detail,
                          isOwner: isOwner,
                          busy: _busy,
                          onAddPhoto: () => _addPhoto(detail.listing),
                          onRemovePhoto: (p) => _removePhoto(detail.listing, p),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: isOwner ? _ownerBar(detail.listing) : _seekerBar(detail.listing),
        );
      },
    );
  }

  Widget _header(Listing l, bool isOwner) {
    final colors = Theme.of(context).colorScheme;
    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: _headerHeight,
      backgroundColor: colors.surface,
      foregroundColor: colors.onSurface,
      leading: Padding(
        padding: const EdgeInsets.all(Gaps.xs),
        child: IconButton.filledTonal(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      actions: [
        if (isOwner && (l.status == 'draft' || l.status == 'published'))
          Padding(
            padding: const EdgeInsets.only(right: Gaps.sm),
            child: IconButton.filledTonal(
              tooltip: 'Change cover image',
              onPressed: _busy ? null : () => _changeCover(l),
              icon: const Icon(Icons.photo_camera_outlined),
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        stretchModes: const [StretchMode.zoomBackground],
        background: ListingCover(
          url: l.coverUrl,
          isFunding: l.isFunding,
          height: _headerHeight + MediaQuery.paddingOf(context).top,
          heroTag: listingHeroTag(l.id),
        ),
      ),
    );
  }

  Widget _barFrame(List<Widget> children) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(top: BorderSide(color: AppColors.of(context).border)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gaps.lg, Gaps.md, Gaps.lg, Gaps.md),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    ),
  );

  /// Owner: the one main action for the status (publish a draft, edit a published listing),
  /// and "More" for the rest.
  Widget? _ownerBar(Listing l) {
    final editable = l.status == 'draft' || l.status == 'published';
    if (!editable) return null;
    final approved = context.read<SessionController>().user?.isApproved ?? false;
    final draft = l.status == 'draft';
    return _barFrame([
      if (_busy) ...[const LinearProgressIndicator(), const SizedBox(height: Gaps.sm)],
      Row(
        children: [
          IconButton.outlined(
            tooltip: 'More actions',
            onPressed: _busy ? null : () => _more(l),
            icon: const Icon(Icons.more_horiz),
          ),
          const SizedBox(width: Gaps.sm),
          Expanded(
            child: AppButton.secondary(
              label: 'Edit',
              icon: Icons.edit_outlined,
              onPressed: _busy ? null : () => _edit(l),
            ),
          ),
          if (draft) ...[
            const SizedBox(width: Gaps.sm),
            Expanded(
              child: AppButton(label: 'Publish', icon: Icons.publish, onPressed: _busy || !approved ? null : _publish),
            ),
          ],
        ],
      ),
      if (draft && !approved)
        Padding(
          padding: const EdgeInsets.only(top: Gaps.sm),
          child: Text(
            'You can publish once an admin approves your account.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
    ]);
  }

  /// Investors and buyers: ask the owner for the confidential details.
  // TODO: wire in Week 9 (access requests): POST /listings/:id/access-requests and show its status.
  Widget _seekerBar(Listing l) => _barFrame([
    AppButton(
      label: 'Request access',
      icon: Icons.lock_open_outlined,
      onPressed: () => showAppToast(
        context,
        'Access requests are coming next. You will be able to ask ${l.ownerName.isEmpty ? 'the owner' : l.ownerName} '
        'for the confidential details here.',
        role: ToneRole.pending,
      ),
    ),
  ]);
}

class _Body extends StatelessWidget {
  const _Body({
    required this.detail,
    required this.isOwner,
    required this.busy,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  final ListingDetail detail;
  final bool isOwner;
  final bool busy;
  final VoidCallback onAddPhoto;
  final ValueChanged<ListingPhoto> onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = AppColors.of(context);
    final l = detail.listing;
    final tone = app.listingType(isFunding: l.isFunding);
    final editable = isOwner && (l.status == 'draft' || l.status == 'published');
    final equity = detail.confidential?.equityOfferedPercent;

    final sections = <Widget>[
      Wrap(
        spacing: Gaps.sm - Gaps.xxs,
        runSpacing: Gaps.sm - Gaps.xxs,
        children: [
          ListingTypeChip(isFunding: l.isFunding),
          if (isOwner) StatusChip.status(listingStatus(l)),
          if (l.isSample) const StatusChip('Sample', icon: Icons.science_outlined),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(top: Gaps.md),
        child: Semantics(header: true, child: Text(l.title, style: theme.textTheme.headlineMedium)),
      ),
      if (!isOwner && l.ownerName.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: Gaps.md),
          child: OwnerChip(name: l.ownerName, subtitle: 'Project owner'),
        ),
      // the money, front and centre
      Padding(
        padding: const EdgeInsets.only(top: Gaps.lg),
        child: AppCard(
          variant: AppCardVariant.tinted,
          role: l.isFunding ? ToneRole.funding : ToneRole.sale,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.isFunding ? 'FUNDING NEEDED' : 'ASKING PRICE',
                      style: theme.textTheme.overline.copyWith(color: tone.fg),
                    ),
                    const SizedBox(height: Gaps.xs),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(formatAmount(l.askingAmount, l.currency), style: theme.textTheme.numeric(size: 26)),
                    ),
                  ],
                ),
              ),
              if (l.isFunding && equity != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('EQUITY', style: theme.textTheme.overline.copyWith(color: tone.fg)),
                    const SizedBox(height: Gaps.xs),
                    Text('${equity % 1 == 0 ? equity.toInt() : equity}%', style: theme.textTheme.numeric(size: 26)),
                  ],
                ),
            ],
          ),
        ),
      ),
      ..._statusBanners(l),
      const SectionHeader('About the project'),
      Text(l.shortDescription, style: theme.textTheme.bodyLarge),
      const SizedBox(height: Gaps.lg),
      Wrap(
        spacing: Gaps.sm,
        runSpacing: Gaps.sm,
        children: [
          CategoryChip(label: l.categoryName),
          StatusChip(projectStages[l.projectStage] ?? l.projectStage, icon: Icons.flag_outlined),
          for (final t in l.techStack) StatusChip(t, icon: Icons.memory),
        ],
      ),
      if (l.photos.isNotEmpty || editable) ...[
        SectionHeader('Photos', subtitle: '${l.photos.length} of $maxListingPhotos'),
        PhotoStrip(
          images: [for (final p in l.photos) NetworkImage(p.url ?? '')],
          onAdd: editable && !busy ? onAddPhoto : null,
          onRemove: editable && !busy ? (i) => onRemovePhoto(l.photos[i]) : null,
        ),
      ],
      if (detail.confidential != null)
        _ConfidentialCard(detail.confidential!, isFunding: l.isFunding)
      else
        const _LockedTeaser(),
      const DisclaimerBanner(margin: EdgeInsets.only(top: Gaps.xl)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final (i, s) in sections.indexed) s.entrance(context, index: i)],
    );
  }

  List<Widget> _statusBanners(Listing l) {
    Widget banner(AppBanner b) => Padding(
      padding: const EdgeInsets.only(top: Gaps.lg),
      child: b,
    );
    return [
      if (isOwner && l.reviewStatus == 'rejected' && l.status == 'draft')
        banner(
          AppBanner(
            role: ToneRole.rejected,
            icon: Icons.feedback_outlined,
            title: 'Not approved',
            message:
                'An admin did not approve this listing: ${l.reviewNote ?? 'no reason given'}. '
                'Edit it and publish again.',
            margin: EdgeInsets.zero,
          ),
        ),
      if (isOwner && l.status == 'published' && l.reviewStatus == 'pending')
        banner(
          const AppBanner(
            role: ToneRole.pending,
            icon: Icons.hourglass_top,
            title: 'Waiting for admin review',
            message: 'Investors and buyers will see it once it is approved.',
            margin: EdgeInsets.zero,
          ),
        ),
      if (l.status == 'suspended')
        banner(
          const AppBanner(
            role: ToneRole.rejected,
            icon: Icons.block,
            title: 'Suspended',
            message: 'An administrator suspended this listing. It is hidden and cannot be changed.',
            margin: EdgeInsets.zero,
          ),
        ),
    ];
  }
}

/// The owner's confidential details, set apart with a lock and a tint.
class _ConfidentialCard extends StatelessWidget {
  const _ConfidentialCard(this.confidential, {required this.isFunding});

  final ListingConfidential confidential;
  final bool isFunding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = AppColors.of(context).verified;
    final rows = <MapEntry<String, String>>[
      for (final e in confidentialLabels.entries)
        if ((confidential.text(e.key) ?? '').isNotEmpty) MapEntry(e.value, confidential.text(e.key)!),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: Gaps.xl),
      child: AppCard(
        variant: AppCardVariant.tinted,
        role: ToneRole.verified,
        padding: const EdgeInsets.all(Gaps.lg + Gaps.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline, color: tone.fg),
                const SizedBox(width: Gaps.sm),
                Expanded(child: Text('Confidential details', style: theme.textTheme.titleLarge)),
              ],
            ),
            const SizedBox(height: Gaps.xs),
            Text(
              'Only you can see this. Approved investors or buyers will, once you grant access.',
              style: theme.textTheme.bodySmall,
            ),
            for (final row in rows) ...[
              const SizedBox(height: Gaps.lg),
              Text(row.key.toUpperCase(), style: theme.textTheme.overline.copyWith(color: tone.fg)),
              const SizedBox(height: Gaps.xs),
              Text(row.value, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

/// What investors and buyers see instead of the confidential details: blurred-looking lines
/// behind a lock, and what they get once the owner approves their request.
class _LockedTeaser extends StatelessWidget {
  const _LockedTeaser();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = AppColors.of(context).verified;
    return Padding(
      padding: const EdgeInsets.only(top: Gaps.xl),
      child: AppCard(
        padding: const EdgeInsets.all(Gaps.lg + Gaps.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(Gaps.sm),
                  decoration: BoxDecoration(color: tone.bg, shape: BoxShape.circle),
                  child: Icon(Icons.lock_outline, color: tone.fg, size: IconSizes.md),
                ),
                const SizedBox(width: Gaps.md),
                Expanded(child: Text('Confidential details', style: theme.textTheme.titleLarge)),
              ],
            ),
            const SizedBox(height: Gaps.lg),
            const ExcludeSemantics(child: SkeletonLines(lines: 4, lineHeight: 10)),
            const SizedBox(height: Gaps.lg),
            Text(
              'Full description, problem, business model, financials and ownership. The owner shares them '
              'after approving your access request.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) => const Skeleton(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkeletonBox(height: 220, radius: 0),
        Padding(
          padding: EdgeInsets.all(Gaps.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 140, height: 24, radius: Radii.pill),
              SizedBox(height: Gaps.lg),
              SkeletonBox(width: 260, height: 26),
              SizedBox(height: Gaps.lg),
              SkeletonBox(height: 72, radius: Radii.lg),
              SizedBox(height: Gaps.xl),
              SkeletonLines(lines: 4),
            ],
          ),
        ),
      ],
    ),
  );
}
