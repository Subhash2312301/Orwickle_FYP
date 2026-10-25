import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/image_widgets.dart';
import '../../auth/widgets/form_widgets.dart';
import '../data/profile_models.dart';

/// One verification document (e.g. CNIC front). Picking a photo uploads it straight away;
/// as a form field it fails validation while a required document is missing.
class DocumentField extends FormField<ProfileDocument?> {
  DocumentField({
    super.key,
    required String label,
    required ProfileDocument? initial,
    required Future<ProfileDocument?> Function(String filePath) onUpload,
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
  final Future<ProfileDocument?> Function(String filePath) onUpload;
  final Future<void> Function() onRemove;

  @override
  State<_DocumentTile> createState() => _DocumentTileState();
}

class _DocumentTileState extends State<_DocumentTile> {
  bool _busy = false;

  Future<void> _pick() async {
    final choice = await pickImage(context, canRemove: widget.state.value != null, allowPdf: true);
    if (choice == null || !mounted) return;
    setState(() => _busy = true);
    try {
      switch (choice) {
        case PickedImage(:final path):
          widget.state.didChange(await widget.onUpload(path));
        case RemoveImage():
          await widget.onRemove();
          widget.state.didChange(null);
      }
    } on ApiException catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final doc = widget.state.value;
    final hasError = widget.state.hasError;

    final Widget preview = doc == null
        ? Icon(Icons.add_a_photo_outlined, color: colors.primary)
        : doc.isPdf || doc.url == null
        ? Icon(Icons.picture_as_pdf_outlined, color: colors.primary)
        : ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              doc.url!,
              width: 56,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(Icons.description_outlined, color: colors.primary),
            ),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: hasError ? colors.error : colors.outlineVariant),
            ),
            child: ListTile(
              onTap: _busy ? null : _pick,
              leading: SizedBox(width: 56, child: Center(child: preview)),
              title: Text(widget.label),
              subtitle: Text(doc == null ? 'Tap to upload a photo or PDF' : 'Uploaded · tap to replace'),
              trailing: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(
                      doc == null ? Icons.upload_outlined : Icons.check_circle,
                      color: doc == null ? null : Colors.green,
                    ),
            ),
          ),
          if (hasError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 12),
              child: Text(widget.state.errorText!, style: TextStyle(color: colors.error, fontSize: 12)),
            ),
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
  Widget build(BuildContext context) => InfoBanner(icon: Icons.privacy_tip_outlined, message: text);
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
