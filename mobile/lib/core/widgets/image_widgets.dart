import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

/// Result of [pickImage]: a picked file path, or a request to remove the current image.
sealed class ImageChoice {}

class PickedImage extends ImageChoice {
  PickedImage(this.path);

  final String path;
}

class RemoveImage extends ImageChoice {}

/// Bottom sheet: gallery, camera, and (when [canRemove]) remove. Images are resized on the
/// phone (max 1600 px, JPEG 85%) so uploads stay well under the 5 MB server limit.
Future<ImageChoice?> pickImage(BuildContext context, {required bool canRemove}) async {
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
  if (source is! ImageSource) return null;
  final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
  return file == null ? null : PickedImage(file.path);
}
