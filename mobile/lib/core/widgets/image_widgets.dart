import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../network/api_client.dart';

/// Profile photo, or the user's initials when there is none (or it fails to load).
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.initials, this.url, this.radius = 24});

  final String initials;
  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fallback = Text(
      initials,
      style: TextStyle(fontSize: radius * 0.75, color: colors.onPrimaryContainer, fontWeight: FontWeight.w500),
    );
    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.primaryContainer,
      child: url == null
          ? fallback
          : ClipOval(
              child: Image.network(
                url!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
            ),
    );
  }
}

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
  final source = await showModalBottomSheet<Object>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          if (allowPdf)
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Choose a PDF file'),
              subtitle: const Text('Up to 5 MB'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
          if (canRemove)
            ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              title: const Text('Remove photo'),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
        ],
      ),
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
