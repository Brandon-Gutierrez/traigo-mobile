/// Adjuntar una foto: tomarla o elegirla y, ya elegida, verla o cambiarla.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../media/photo_picker.dart';
import '../network/upload_file.dart';
import '../theme/app_theme.dart';
import 'chamfer.dart';

/// El tamaño máximo que acepta el backend.
const maxUploadBytes = 5 * 1024 * 1024;

/// Pide la foto y, si no se puede abrir la cámara o la galería, lo explica.
Future<UploadFile?> pickPhoto(BuildContext context, WidgetRef ref, PhotoSource source) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    return await ref.read(photoPickerProvider).pick(source);
  } on PlatformException {
    messenger.showSnackBar(SnackBar(
      content: Text(
        source == PhotoSource.camera
            ? 'No se pudo abrir la cámara. Revisa los permisos de la app.'
            : 'No se pudo abrir la galería. Revisa los permisos de la app.',
      ),
    ));
    return null;
  }
}

/// `820 KB`, `1,2 MB`.
String fileSizeLabel(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceFirst('.', ',')} MB';
}

/// El tamaño del archivo, o `null` si no se puede leer.
int? _sizeOf(String path) {
  try {
    return File(path).lengthSync();
  } on FileSystemException {
    return null;
  }
}

class PhotoField extends ConsumerWidget {
  const PhotoField({
    super.key,
    required this.file,
    required this.onChanged,
    this.enabled = true,
  });

  final UploadFile? file;
  final ValueChanged<UploadFile?> onChanged;
  final bool enabled;

  Future<void> _pick(BuildContext context, WidgetRef ref, PhotoSource source) async {
    final photo = await pickPhoto(context, ref, source);
    if (photo == null || !context.mounted) return;
    final size = _sizeOf(photo.path);
    if (size != null && size > maxUploadBytes) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('La foto pesa más de 5 MB. Elige otra o tómala de nuevo.'),
      ));
      return;
    }
    onChanged(photo);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = this.file;
    VoidCallback? pick(PhotoSource source) =>
        enabled ? () => _pick(context, ref, source) : null;

    if (file == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SourceButton(
            icon: Icons.photo_camera_outlined,
            label: 'Tomar foto',
            onTap: pick(PhotoSource.camera),
          ),
          const SizedBox(height: 8),
          _SourceButton(
            icon: Icons.image_outlined,
            label: 'Elegir de la galería',
            onTap: pick(PhotoSource.gallery),
          ),
        ],
      );
    }

    final size = _sizeOf(file.path);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ChamferBox(
              color: AppColors.alt,
              padding: EdgeInsets.zero,
              cut: 10,
              child: SizedBox.square(
                dimension: 56,
                child: Image.file(
                  File(file.path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.image_outlined, color: AppColors.ink),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.filename,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(15, FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    size == null ? 'Lista para enviar' : '${fileSizeLabel(size)} · lista para enviar',
                    style: AppText.mono(12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Quitar foto',
              onPressed: enabled ? () => onChanged(null) : null,
              icon: const Icon(Icons.close, color: AppColors.ink),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _SourceButton(
          icon: Icons.photo_camera_outlined,
          label: 'Tomar otra foto',
          onTap: pick(PhotoSource.camera),
        ),
      ],
    );
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: AppColors.alt,
        shape: const Border(bottom: BorderSide(color: AppColors.ink, width: 3)),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: AppColors.ink),
                  const SizedBox(width: 10),
                  Expanded(child: Text(label, style: AppText.body(15, FontWeight.w600))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
