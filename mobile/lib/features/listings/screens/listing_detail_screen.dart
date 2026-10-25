import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/image_widgets.dart';
import '../../auth/session/session_controller.dart';
import '../../auth/widgets/form_widgets.dart';
import '../data/listing_api.dart';
import '../data/listing_models.dart';
import '../widgets/listing_widgets.dart';

/// Owner's view of one listing: preview, confidential details and the actions allowed in its status.
class ListingDetailScreen extends StatefulWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  late Future<ListingDetail> _detail = _load();
  bool _busy = false;

  ListingApi get _api => context.read<ListingApi>();

  Future<ListingDetail> _load() => context.read<ListingApi>().get(widget.listingId);

  void _reload() => setState(() => _detail = _load());

  Future<void> _run(Future<ListingDetail> Function() action, String doneMessage) async {
    setState(() => _busy = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() => _detail = Future.value(updated));
      showInfoSnack(context, doneMessage);
    } on ApiException catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
          ],
        ),
      ) ??
      false;

  // Changing a live listing (edit, cover, photos) hides it again until an admin re-approves it,
  // so the owner is warned first.
  Future<bool> _confirmLiveChange(Listing listing, String what) async =>
      !listing.isLive ||
      await _confirm(
        'Change a live listing?',
        'After you $what, the listing goes back to admin review and is hidden from investors and buyers '
            'until it is approved again.',
        'Continue',
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
    if (!await _confirm('Remove photo?', 'The photo is deleted from this listing.', 'Remove')) return;
    if (!await _confirmLiveChange(listing, 'remove a photo')) return;
    await _run(() => _api.removePhoto(listing.id, photo.id), 'Photo removed');
  }

  Future<void> _publish() async {
    if (await _confirm(
      'Publish listing?',
      'Investors and buyers will be able to see the public preview. Your confidential details stay private. '
          'An administrator will review the listing.',
      'Publish',
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
    if (await _confirm('Close listing?', 'A closed listing can no longer be edited or published.', 'Close')) {
      await _run(() => _api.changeStatus(widget.listingId, 'close'), 'Listing closed');
    }
  }

  Future<void> _delete() async {
    if (!await _confirm('Delete draft?', 'This cannot be undone.', 'Delete')) return;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Listing')),
      body: FutureBuilder<ListingDetail>(
        future: _detail,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final message = snapshot.error is ApiException
                ? (snapshot.error! as ApiException).message
                : 'Could not load the listing.';
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message),
                  TextButton(onPressed: _reload, child: const Text('Try again')),
                ],
              ),
            );
          }
          final detail = snapshot.data!;
          final l = detail.listing;
          final editable = l.status == 'draft' || l.status == 'published';
          final theme = Theme.of(context);

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              Stack(
                children: [
                  ListingCover(url: l.coverUrl, isFunding: l.isFunding, height: 200),
                  if (editable)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: FilledButton.tonalIcon(
                        onPressed: _busy ? null : () => _changeCover(l),
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: Text(l.coverUrl == null ? 'Add cover' : 'Change cover'),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListingChips(l),
                    const SizedBox(height: 12),
                    Text(l.title, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(
                      '${l.isFunding ? 'Funding needed' : 'Asking price'}: ${formatAmount(l.askingAmount, l.currency)}',
                      style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 12),
                    Text(l.shortDescription),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Chip(avatar: const Icon(Icons.category_outlined, size: 16), label: Text(l.categoryName)),
                        Chip(
                          avatar: const Icon(Icons.flag_outlined, size: 16),
                          label: Text(projectStages[l.projectStage] ?? l.projectStage),
                        ),
                        for (final t in l.techStack) Chip(label: Text(t)),
                      ],
                    ),
                    if (l.photos.isNotEmpty || editable) ...[
                      const SizedBox(height: 16),
                      Text('Photos (${l.photos.length}/$maxListingPhotos)', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      PhotoStrip(
                        images: [for (final p in l.photos) NetworkImage(p.url ?? '')],
                        onAdd: editable && !_busy ? () => _addPhoto(l) : null,
                        onRemove: editable && !_busy ? (i) => _removePhoto(l, l.photos[i]) : null,
                      ),
                    ],
                    if (l.reviewStatus == 'rejected' && l.status == 'draft')
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: InfoBanner(
                          isError: true,
                          icon: Icons.feedback_outlined,
                          message:
                              'An admin did not approve this listing: ${l.reviewNote ?? 'no reason given'}. '
                              'Edit it and publish again.',
                        ),
                      ),
                    if (l.status == 'published' && l.reviewStatus == 'pending')
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: InfoBanner(
                          icon: Icons.hourglass_top,
                          message: 'Waiting for admin review. Investors and buyers will see it once approved.',
                        ),
                      ),
                    if (l.status == 'suspended')
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: InfoBanner(
                          isError: true,
                          icon: Icons.block,
                          message: 'An administrator suspended this listing. It is hidden and cannot be changed.',
                        ),
                      ),
                    if (detail.confidential != null) _ConfidentialCard(detail.confidential!, isFunding: l.isFunding),
                    const SizedBox(height: 20),
                    if (_busy) const LinearProgressIndicator(),
                    ..._actions(l),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _actions(Listing l) {
    final approved = context.read<SessionController>().user?.isApproved ?? false;
    final buttons = <Widget>[
      if (l.status == 'draft') ...[
        FilledButton.icon(
          onPressed: _busy || !approved ? null : _publish,
          icon: const Icon(Icons.publish),
          label: const Text('Publish'),
        ),
        if (!approved)
          Text(
            'You can publish once an admin approves your account.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
      if (l.status == 'draft' || l.status == 'published')
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _edit(l),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit'),
        ),
      if (l.status == 'published')
        OutlinedButton.icon(
          onPressed: _busy ? null : _unpublish,
          icon: const Icon(Icons.visibility_off_outlined),
          label: const Text('Unpublish'),
        ),
      if (l.status == 'draft' || l.status == 'published')
        TextButton.icon(
          onPressed: _busy ? null : _close,
          icon: const Icon(Icons.lock_outline),
          label: const Text('Close listing'),
        ),
      if (l.status == 'draft')
        TextButton.icon(
          onPressed: _busy ? null : _delete,
          icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
          label: Text('Delete draft', style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
    ];
    return [for (final b in buttons) Padding(padding: const EdgeInsets.only(bottom: 8), child: b)];
  }
}

class _ConfidentialCard extends StatelessWidget {
  const _ConfidentialCard(this.confidential, {required this.isFunding});

  final ListingConfidential confidential;
  final bool isFunding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final equity = confidential.equityOfferedPercent;
    final rows = <MapEntry<String, String>>[
      if (isFunding && equity != null) MapEntry('Equity offered', '${equity % 1 == 0 ? equity.toInt() : equity}%'),
      for (final e in confidentialLabels.entries)
        if ((confidential.text(e.key) ?? '').isNotEmpty) MapEntry(e.value, confidential.text(e.key)!),
    ];
    return Card(
      margin: const EdgeInsets.only(top: 20),
      color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline, color: theme.colorScheme.tertiary),
                const SizedBox(width: 8),
                Text('Confidential details', style: theme.textTheme.titleMedium),
              ],
            ),
            Text('Only you can see this section.', style: theme.textTheme.bodySmall),
            for (final row in rows) ...[
              const SizedBox(height: 12),
              Text(row.key, style: theme.textTheme.labelLarge),
              const SizedBox(height: 2),
              Text(row.value),
            ],
          ],
        ),
      ),
    );
  }
}
