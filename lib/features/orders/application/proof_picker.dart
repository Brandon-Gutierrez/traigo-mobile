import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/upload_file.dart';

enum ProofSource { camera, gallery }

/// Toma o elige la foto de un comprobante.
abstract interface class ProofPicker {
  /// `null` si la persona se arrepiente. Puede lanzar [PlatformException] si
  /// no dio permiso.
  Future<UploadFile?> pick(ProofSource source);
}

class DeviceProofPicker implements ProofPicker {
  final ImagePicker _picker = ImagePicker();

  @override
  Future<UploadFile?> pick(ProofSource source) async {
    final photo = await _picker.pickImage(
      source: source == ProofSource.camera ? ImageSource.camera : ImageSource.gallery,
      // Alcanza para leer el comprobante y queda muy por debajo de los 5 MB.
      maxWidth: 1600,
      maxHeight: 2400,
      imageQuality: 85,
      // No pide acceso a toda la galería.
      requestFullMetadata: false,
    );
    return photo == null ? null : UploadFile(path: photo.path, filename: photo.name);
  }
}

final proofPickerProvider = Provider<ProofPicker>((ref) => DeviceProofPicker());
