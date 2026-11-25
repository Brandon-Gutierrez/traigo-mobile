/// Fotos de comprobantes de pago y de evidencia.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../network/upload_file.dart';

enum PhotoSource { camera, gallery }

/// Toma o elige una foto.
abstract interface class PhotoPicker {
  /// `null` si la persona se arrepiente. Puede lanzar [PlatformException] si
  /// no dio permiso.
  Future<UploadFile?> pick(PhotoSource source);
}

class DevicePhotoPicker implements PhotoPicker {
  final ImagePicker _picker = ImagePicker();

  @override
  Future<UploadFile?> pick(PhotoSource source) async {
    final photo = await _picker.pickImage(
      source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
      // Alcanza para leer un comprobante y queda muy por debajo de los 5 MB.
      maxWidth: 1600,
      maxHeight: 2400,
      imageQuality: 85,
      // No pide acceso a toda la galería.
      requestFullMetadata: false,
    );
    return photo == null ? null : UploadFile(path: photo.path, filename: photo.name);
  }
}

final photoPickerProvider = Provider<PhotoPicker>((ref) => DevicePhotoPicker());
