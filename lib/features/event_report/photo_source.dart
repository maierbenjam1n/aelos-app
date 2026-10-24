import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

enum PhotoOrigin { camera, library }

/// What came back from the camera or library.
sealed class PhotoPick {
  const PhotoPick();
}

final class PhotoPicked extends PhotoPick {
  const PhotoPicked(this.bytes);

  final Uint8List bytes;
}

/// The person closed the camera or picker without choosing.
final class PhotoCancelled extends PhotoPick {
  const PhotoCancelled();
}

/// Access was refused or no camera exists; [message] says what to do, calmly.
final class PhotoUnavailable extends PhotoPick {
  const PhotoUnavailable(this.message);

  final String message;
}

/// Takes or chooses one photo, downscaled so a six-photo report stays small
/// in memory. Overridable so screenshots and the demo can stub it.
final photoSourceProvider = Provider<PhotoSource>((ref) => ImagePickerPhotoSource());

abstract interface class PhotoSource {
  Future<PhotoPick> pick(PhotoOrigin origin);
}

class ImagePickerPhotoSource implements PhotoSource {
  final _picker = ImagePicker();

  @override
  Future<PhotoPick> pick(PhotoOrigin origin) async {
    try {
      final file = await _picker.pickImage(
        source: origin == PhotoOrigin.camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (file == null) return const PhotoCancelled();
      return PhotoPicked(await file.readAsBytes());
    } on PlatformException catch (e) {
      return PhotoUnavailable(switch (e.code) {
        'camera_access_denied' || 'camera_access_restricted' =>
          'Aelos isn’t allowed to use the camera. You can allow it in Settings, or choose a photo from your library.',
        'photo_access_denied' || 'photo_access_restricted' =>
          'Aelos isn’t allowed to see your photos. You can allow it in Settings, or take the photo now.',
        'no_available_camera' => 'There’s no camera available here. Choose a photo from your library instead.',
        _ => 'The photo couldn’t be opened. Please try once more.',
      });
    } on Object {
      return const PhotoUnavailable('The photo couldn’t be opened. Please try once more.');
    }
  }
}
