import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/image_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../data/profile_models.dart';

/// Result of [pickEvidence]: a file to upload, a link, or a request to remove the current item.
sealed class EvidenceChoice {}

class EvidenceFile extends EvidenceChoice {
  EvidenceFile(this.file);

  final UploadFile file;
}

class EvidenceLink extends EvidenceChoice {
  EvidenceLink(this.url);

  final String url;
}

class EvidenceRemove extends EvidenceChoice {}

/// Bottom sheet for a piece of evidence: a photo or PDF, a link (e.g. a portfolio page) and,
/// when [canRemove], remove.
Future<EvidenceChoice?> pickEvidence(BuildContext context, {required String title, required bool canRemove}) async {
  final choice = await showAppBottomSheet<String>(
    context,
    title: title,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetOption(
          icon: Icons.upload_file_outlined,
          label: 'Upload a photo or PDF',
          subtitle: 'Up to 5 MB',
          onTap: () => Navigator.pop(context, 'file'),
        ),
        SheetOption(
          icon: Icons.link,
          label: 'Add a link',
          subtitle: 'A public page that shows it',
          onTap: () => Navigator.pop(context, 'link'),
        ),
        if (canRemove)
          SheetOption(
            icon: Icons.delete_outline,
            label: 'Remove',
            destructive: true,
            onTap: () => Navigator.pop(context, 'remove'),
          ),
      ],
    ),
  );
  if (!context.mounted) return null;
  switch (choice) {
    case 'remove':
      return EvidenceRemove();
    case 'link':
      final url = await askForLink(context, title: title);
      return url == null ? null : EvidenceLink(url);
    case 'file':
      final picked = await pickImage(context, canRemove: false, allowPdf: true);
      return picked is PickedImage ? EvidenceFile(picked.file) : null;
  }
  return null;
}

/// Dialog asking for one https:// link; null when cancelled.
Future<String?> askForLink(BuildContext context, {required String title}) {
  final form = GlobalKey<FormState>();
  final controller = TextEditingController();
  void submit(BuildContext dialog) {
    if (form.currentState!.validate()) Navigator.pop(dialog, controller.text.trim());
  }

  return showDialog<String>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(title),
      content: Form(
        key: form,
        child: AppTextField(
          controller: controller,
          label: 'Link',
          hint: 'https://...',
          icon: Icons.link,
          keyboardType: TextInputType.url,
          validator: Validators.requiredUrl('Link'),
          onSubmitted: (_) => submit(dialog),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
        FilledButton(onPressed: () => submit(dialog), child: const Text('Add link')),
      ],
    ),
  ).whenComplete(controller.dispose);
}

/// One verification document (e.g. CNIC front) or piece of evidence. Picking a file uploads it straight away;
/// with [onLink] the user may give a link instead. As a form field it fails validation while a required
/// document is missing.
class DocumentField extends FormField<ProfileDocument?> {
  DocumentField({
    super.key,
    required String label,
    required ProfileDocument? initial,
    required Future<ProfileDocument?> Function(UploadFile file) onUpload,
    required Future<void> Function() onRemove,
    Future<ProfileDocument?> Function(String url)? onLink,
    String? hint,
    bool required = true,
    String? serverError,
  }) : super(
         initialValue: initial,
         forceErrorText: serverError,
         validator: (doc) => required && doc == null ? 'Upload $label' : null,
         builder: (state) => _DocumentTile(
           state: state,
           label: label,
           hint: hint,
           onUpload: onUpload,
           onRemove: onRemove,
           onLink: onLink,
         ),
       );
}

class _DocumentTile extends StatefulWidget {
  const _DocumentTile({
    required this.state,
    required this.label,
    required this.onUpload,
    required this.onRemove,
    this.onLink,
    this.hint,
  });

  final FormFieldState<ProfileDocument?> state;
  final String label;
  final String? hint;
  final Future<ProfileDocument?> Function(UploadFile file) onUpload;
  final Future<void> Function() onRemove;
  final Future<ProfileDocument?> Function(String url)? onLink;

  @override
  State<_DocumentTile> createState() => _DocumentTileState();
}

class _DocumentTileState extends State<_DocumentTile> {
  bool _busy = false;

  static const double _thumb = 56;

  String get _title => widget.label[0].toUpperCase() + widget.label.substring(1);

  Future<void> _pick() async {
    final canRemove = widget.state.value != null;
    final EvidenceChoice? choice = widget.onLink != null
        ? await pickEvidence(context, title: _title, canRemove: canRemove)
        : switch (await pickImage(context, canRemove: canRemove, allowPdf: true)) {
            PickedImage(:final file) => EvidenceFile(file),
            RemoveImage() => EvidenceRemove(),
            null => null,
          };
    if (choice == null || !mounted) return;
    setState(() => _busy = true);
    try {
      switch (choice) {
        case EvidenceFile(:final file):
          widget.state.didChange(await widget.onUpload(file));
        case EvidenceLink(:final url):
          widget.state.didChange(await widget.onLink!(url));
        case EvidenceRemove():
          await widget.onRemove();
          widget.state.didChange(null);
      }
    } on ApiException catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final app = AppColors.of(context);
    final doc = widget.state.value;
    final hasError = widget.state.hasError;
    // labels are written to follow "Upload …", so the title starts with a capital
    final title = _title;
    final linkable = widget.onLink != null;

    final Widget preview = doc == null
        ? Icon(linkable ? Icons.add_link : Icons.add_a_photo_outlined, color: colors.primary)
        : doc.isLink
        ? Icon(Icons.link, color: colors.primary)
        : doc.isPdf || doc.url == null
        ? Icon(Icons.picture_as_pdf_outlined, color: colors.primary)
        : Image.network(
            doc.url!,
            width: _thumb,
            height: _thumb,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Icon(Icons.description_outlined, color: colors.primary),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: Gaps.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: Motion.of(context, Motion.base),
            decoration: BoxDecoration(
              color: doc == null ? colors.surface : app.approved.bg.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(color: hasError ? colors.error : (doc == null ? app.border : app.approved.fg)),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: _busy ? null : _pick,
                borderRadius: BorderRadius.circular(Radii.lg),
                child: Padding(
                  padding: const EdgeInsets.all(Gaps.md),
                  child: Row(
                    children: [
                      Container(
                        width: _thumb,
                        height: _thumb,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                        child: Center(child: preview),
                      ),
                      const SizedBox(width: Gaps.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: theme.textTheme.titleSmall),
                            const SizedBox(height: Gaps.xxs),
                            Text(
                              switch (doc) {
                                null when linkable => widget.hint ?? 'Tap to upload a file or add a link',
                                null => 'Tap to upload a photo or PDF',
                                ProfileDocument(isLink: true) => '${doc.url ?? 'Link added'} · tap to change',
                                _ => 'Uploaded · tap to replace',
                              },
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Gaps.sm),
                      AnimatedSwitcher(
                        duration: Motion.of(context, Motion.fast),
                        child: _busy
                            ? const SizedBox.square(
                                key: ValueKey('busy'),
                                dimension: IconSizes.md,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                doc == null ? Icons.upload_outlined : Icons.check_circle,
                                key: ValueKey(doc == null),
                                color: doc == null ? colors.onSurfaceVariant : app.approved.fg,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          FieldError(widget.state.errorText),
        ],
      ),
    );
  }
}

/// Short notice shown above identity documents.
class PrivacyNote extends StatelessWidget {
  const PrivacyNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => AppBanner(icon: Icons.lock_outline, role: ToneRole.info, message: text);
}

/// Fails validation until the user has added at least [min] items; shows the count so far.
class EvidenceCountField extends FormField<int> {
  EvidenceCountField({super.key, required int count, required int min, String? serverError})
    : super(
        initialValue: count,
        forceErrorText: serverError,
        validator: (_) => count < min ? 'Add at least $min pieces of supporting evidence' : null,
        builder: (state) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$count of at least $min added',
              style: Theme.of(state.context).textTheme.labelLarge
                  ?.copyWith(color: count >= min ? AppColors.of(state.context).approved.fg : null),
            ),
            FieldError(state.errorText),
          ],
        ),
      );
}
