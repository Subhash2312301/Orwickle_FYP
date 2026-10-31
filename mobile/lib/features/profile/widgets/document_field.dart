import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/image_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../data/profile_models.dart';

/// One verification document (e.g. CNIC front). Picking a photo uploads it straight away;
/// as a form field it fails validation while a required document is missing.
class DocumentField extends FormField<ProfileDocument?> {
  DocumentField({
    super.key,
    required String label,
    required ProfileDocument? initial,
    required Future<ProfileDocument?> Function(UploadFile file) onUpload,
    required Future<void> Function() onRemove,
    bool required = true,
    String? serverError,
  }) : super(
         initialValue: initial,
         forceErrorText: serverError,
         validator: (doc) => required && doc == null ? 'Upload $label' : null,
         builder: (state) => _DocumentTile(state: state, label: label, onUpload: onUpload, onRemove: onRemove),
       );
}

class _DocumentTile extends StatefulWidget {
  const _DocumentTile({required this.state, required this.label, required this.onUpload, required this.onRemove});

  final FormFieldState<ProfileDocument?> state;
  final String label;
  final Future<ProfileDocument?> Function(UploadFile file) onUpload;
  final Future<void> Function() onRemove;

  @override
  State<_DocumentTile> createState() => _DocumentTileState();
}

class _DocumentTileState extends State<_DocumentTile> {
  bool _busy = false;

  static const double _thumb = 56;

  Future<void> _pick() async {
    final choice = await pickImage(context, canRemove: widget.state.value != null, allowPdf: true);
    if (choice == null || !mounted) return;
    setState(() => _busy = true);
    try {
      switch (choice) {
        case PickedImage(:final file):
          widget.state.didChange(await widget.onUpload(file));
        case RemoveImage():
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
    // labels are written to follow "Upload …", so start the title with a capital
    final title = widget.label[0].toUpperCase() + widget.label.substring(1);

    final Widget preview = doc == null
        ? Icon(Icons.add_a_photo_outlined, color: colors.primary)
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
                              doc == null ? 'Tap to upload a photo or PDF' : 'Uploaded · tap to replace',
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

/// Types 4210112345671 as 42101-1234567-1 while the user enters a CNIC.
class CnicInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp('[^0-9]'), '');
    final capped = digits.length > 13 ? digits.substring(0, 13) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      if (i == 5 || i == 12) buffer.write('-');
      buffer.write(capped[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// 4210112345671 → 42101-1234567-1
String formatCnic(String? digits) => digits == null
    ? ''
    : CnicInputFormatter().formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: digits)).text;
