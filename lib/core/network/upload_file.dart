/// Archivo que se sube al backend (comprobante de pago o evidencia).
class UploadFile {
  const UploadFile({required this.path, required this.filename});

  final String path;
  final String filename;
}
