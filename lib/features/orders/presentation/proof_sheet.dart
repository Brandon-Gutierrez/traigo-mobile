import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/media/photo_picker.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/cut_button.dart';
import '../../../core/ui/form_pieces.dart';
import '../../auth/presentation/auth_frame.dart' show FormError;
import '../domain/orders.dart';

/// De dónde sale la foto del comprobante. Devuelve la elección.
Future<PhotoSource?> chooseProofSource(BuildContext context) {
  return showModalBottomSheet<PhotoSource>(
    context: context,
    useRootNavigator: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Foto del comprobante', style: AppText.display(22)),
            const SizedBox(height: 4),
            Text(
              'Que se vean el monto y el número de referencia.',
              style: AppText.body(14, FontWeight.w400, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            CutButton(
              label: 'Tomar foto',
              onPressed: () => Navigator.pop(context, PhotoSource.camera),
            ),
            const SizedBox(height: 10),
            CutButton(
              label: 'Elegir de la galería',
              color: AppColors.ink,
              onPressed: () => Navigator.pop(context, PhotoSource.gallery),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Revisar la foto, anotar la referencia (si se quiere) y enviarla a Jime.
/// Devuelve el pedido actualizado si se envió.
Future<OrderDetail?> reviewAndSendProof(
  BuildContext context, {
  required String orderId,
  required UploadFile file,
}) {
  return showModalBottomSheet<OrderDetail>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => _ProofSheet(orderId: orderId, file: file),
  );
}

class _ProofSheet extends ConsumerStatefulWidget {
  const _ProofSheet({required this.orderId, required this.file});

  final String orderId;
  final UploadFile file;

  @override
  ConsumerState<_ProofSheet> createState() => _ProofSheetState();
}

class _ProofSheetState extends ConsumerState<_ProofSheet> {
  /// La misma clave en cada reintento: no se sube dos veces.
  final _requestKey = const Uuid().v4();
  final _reference = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final reference = _reference.text.trim();
      final order = await ref.read(ordersRepositoryProvider).uploadProof(
            widget.orderId,
            file: widget.file,
            clientUuid: _requestKey,
            reference: reference.isEmpty ? null : reference,
          );
      if (mounted) Navigator.pop(context, order);
    } on ApiException catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          18,
          16,
          18,
          18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Revisa la foto', style: AppText.display(22)),
            const SizedBox(height: 10),
            SizedBox(
              height: 220,
              child: ColoredBox(
                color: AppColors.alt,
                child: Image.file(
                  File(widget.file.path),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Center(
                    child: Text(widget.file.filename, style: AppText.mono(13)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'Número de referencia (opcional)',
              controller: _reference,
              mono: true,
              enabled: !_busy,
              inputFormatters: [LengthLimitingTextInputFormatter(40)],
            ),
            if (error != null) ...[const SizedBox(height: 10), FormError(error)],
            const SizedBox(height: 14),
            CutButton(
              label: _busy ? 'Enviando…' : 'Enviar a Jime',
              onPressed: _send,
              busy: _busy,
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
