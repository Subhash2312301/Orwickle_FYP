import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../network/api_client.dart';
import 'overlays.dart';

/// Result of [pickImage]: a picked file, or a request to remove the current image.
sealed class ImageChoice {}

class PickedImage extends ImageChoice {
  PickedImage(this.file);

  final UploadFile file;
}

class RemoveImage extends ImageChoice {}

/// Bottom sheet: gallery, camera, a PDF file (when [allowPdf], for documents such as a bank statement)
/// and (when [canRemove]) remove. Images are resized on the phone (max 1600 px, JPEG 85%) so uploads
/// stay well under the 5 MB server limit.
Future<ImageChoice?> pickImage(BuildContext context, {required bool canRemove, bool allowPdf = false}) async {
  final source = await showAppBottomSheet<Object>(
    context,
    title: allowPdf ? 'Add a document' : 'Add a photo',
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetOption(
          icon: Icons.photo_library_outlined,
          label: 'Choose from gallery',
          onTap: () => Navigator.pop(context, ImageSource.gallery),
        ),
        SheetOption(
          icon: Icons.photo_camera_outlined,
          label: 'Take a photo',
          onTap: () => Navigator.pop(context, ImageSource.camera),
        ),
        if (allowPdf)
          SheetOption(
            icon: Icons.picture_as_pdf_outlined,
            label: 'Choose a PDF file',
            subtitle: 'Up to 5 MB',
            onTap: () => Navigator.pop(context, 'pdf'),
          ),
        if (canRemove)
          SheetOption(
            icon: Icons.delete_outline,
            label: 'Remove photo',
            destructive: true,
            onTap: () => Navigator.pop(context, 'remove'),
          ),
      ],
    ),
  );
  if (source == 'remove') return RemoveImage();
  if (source == 'pdf') {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['pdf']);
    return file == null ? null : PickedImage(UploadFile(file.name, await file.xFile.readAsBytes()));
  }
  if (source is! ImageSource) return null;
  final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
  return file == null ? null : PickedImage(UploadFile(file.name, await file.readAsBytes()));
}
