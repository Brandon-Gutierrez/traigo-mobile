/// Entrega un archivo (los reportes de Excel) a la hoja de compartir del
/// celular: guardarlo, mandarlo por WhatsApp o correo.
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

const xlsxMimeType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

abstract interface class ReportSharer {
  /// Puede lanzar [PlatformException] si el celular no puede compartirlo.
  Future<void> share(String filename, List<int> bytes);
}

class DeviceReportSharer implements ReportSharer {
  @override
  Future<void> share(String filename, List<int> bytes) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(Uint8List.fromList(bytes), mimeType: xlsxMimeType)],
        fileNameOverrides: [filename],
      ),
    );
  }
}

final reportSharerProvider = Provider<ReportSharer>((ref) => DeviceReportSharer());
