/// Confirmaciones, pedidos de motivo y botones de acción.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'cut_button.dart';
import 'form_pieces.dart';

/// Pide confirmar algo. `true` solo si la persona toca [action].
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      scrollable: true,
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Volver')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: destructive ? TextButton.styleFrom(foregroundColor: AppColors.alert) : null,
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Pide un motivo (obligatorio). `null` si la persona se arrepiente.
Future<String?> askReason(
  BuildContext context, {
  required String title,
  required String label,
  required String action,
  String? body,
  bool destructive = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ReasonDialog(
      title: title,
      body: body,
      label: label,
      action: action,
      destructive: destructive,
    ),
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.label,
    required this.action,
    required this.destructive,
    this.body,
  });

  final String title;
  final String? body;
  final String label;
  final String action;
  final bool destructive;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = widget.body;
    final reason = _reason.text.trim();
    return AlertDialog(
      title: Text(widget.title),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (body != null) ...[Text(body), const SizedBox(height: 12)],
          LabeledField(
            label: widget.label,
            controller: _reason,
            lines: 2,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(300)],
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Volver')),
        TextButton(
          onPressed: reason.isEmpty ? null : () => Navigator.pop(context, reason),
          style: widget.destructive
              ? TextButton.styleFrom(foregroundColor: AppColors.alert)
              : null,
          child: Text(widget.action),
        ),
      ],
    );
  }
}

/// Botón principal para una acción que tarda: muestra que está trabajando y no
/// deja tocar dos veces.
class ActionButton extends StatefulWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.confirm,
    this.color = AppColors.violet,
    this.height = 58,
    this.fontSize = 20,
  });

  final String label;

  /// `null` = deshabilitado; [label] explica qué falta.
  final Future<void> Function()? onPressed;

  /// Pregunta antes de [onPressed]. Mientras la ventana está abierta el botón
  /// todavía no está trabajando.
  final Future<bool> Function()? confirm;
  final Color color;
  final double height;
  final double fontSize;

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool _busy = false;

  /// Hay una pregunta abierta: otro toque no abre una segunda.
  bool _asking = false;

  Future<void> _run() async {
    final confirm = widget.confirm;
    if (confirm != null) {
      if (_asking) return;
      _asking = true;
      final ok = await confirm();
      _asking = false;
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CutButton(
      label: widget.label,
      color: widget.color,
      height: widget.height,
      fontSize: widget.fontSize,
      busy: _busy,
      onPressed: widget.onPressed == null ? null : _run,
    );
  }
}
