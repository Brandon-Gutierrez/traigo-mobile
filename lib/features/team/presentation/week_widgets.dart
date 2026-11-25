/// Textos y piezas que comparten «Mi semana», «Evidencia» y sus detalles.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/chamfer.dart';
import '../../../core/ui/ficha.dart';
import '../domain/bonus.dart';
import '../domain/kpi.dart';
import '../domain/my_week.dart';

/// `22`, `99,6`.
String kpiNumber(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1).replaceFirst('.', ',');

/// «22 / 27», «99,6 / 99 %» y «— / 27» si Jime todavía no carga el valor.
String kpiProgress(WeekIndicator item) {
  final actual = item.indicator.actual;
  final suffix = item.unit == KpiUnit.percent ? ' %' : '';
  return '${actual == null ? '—' : kpiNumber(actual)} / '
      '${kpiNumber(item.indicator.target)}$suffix';
}

/// `30/11`.
String dayMonth(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

(MarkKind, String) complianceMark(Compliance compliance) => switch (compliance) {
      Compliance.passes => (MarkKind.ok, 'Cumple'),
      Compliance.fails => (MarkKind.bad, 'No cumple'),
      Compliance.pending => (MarkKind.pending, 'Pendiente'),
    };

/// El estado de la evidencia de un indicador, dicho como en el diseño.
(MarkKind, String) evidenceMark(WeekIndicator item) {
  final status = item.indicator.evidence;
  return switch (status) {
    EvidenceStatus.missing => (MarkKind.pending, 'Sin evidencia'),
    EvidenceStatus.validated => (MarkKind.ok, 'Validada por Jime'),
    EvidenceStatus.observed => (MarkKind.bad, 'Observada por Jime'),
    EvidenceStatus.inReview => (MarkKind.pending, '${_countInReview(item)} · En revisión'),
  };
}

/// «3 enlaces», «1 foto» o, si hay de varios tipos, «2 evidencias».
String _countInReview(WeekIndicator item) {
  final sent = item.evidence.where((e) => e.status == EvidenceStatus.inReview).toList();
  final count = sent.isEmpty ? 1 : sent.length;
  final kinds = {for (final e in sent) e.kind};
  final (one, many) = switch (kinds.length == 1 ? kinds.single : null) {
    EvidenceKind.photo => ('foto', 'fotos'),
    EvidenceKind.link => ('enlace', 'enlaces'),
    EvidenceKind.order => ('pedido', 'pedidos'),
    null => ('evidencia', 'evidencias'),
  };
  return '$count ${count == 1 ? one : many}';
}

MarkKind deliverableMark(DeliverableStatus status) => switch (status) {
      DeliverableStatus.onTime => MarkKind.ok,
      DeliverableStatus.late || DeliverableStatus.notValidated => MarkKind.bad,
      DeliverableStatus.pending || DeliverableStatus.inReview => MarkKind.pending,
    };

/// Una fila que abre su detalle: texto a la izquierda y flecha a la derecha.
class OpenRow extends StatelessWidget {
  const OpenRow({super.key, required this.onTap, required this.children});

  final VoidCallback onTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.rule, width: 2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

/// Una entrega de Sistemas en una lista.
class DeliverableRow extends StatelessWidget {
  const DeliverableRow(this.deliverable, {super.key, required this.onTap});

  final Deliverable deliverable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OpenRow(
      onTap: onTap,
      children: [
        Text(deliverable.title, style: AppText.body(14.5, FontWeight.w600, height: 1.2)),
        const SizedBox(height: 2),
        Text('VENCE ${dayMonth(deliverable.dueOn)}',
            style: AppText.mono(11.5, color: AppColors.muted)),
        const SizedBox(height: 3),
        StatusMark(deliverableMark(deliverable.status), deliverable.status.label),
      ],
    );
  }
}

/// Aviso con una barra a la izquierda: rojo para lo que Jime observó.
class SideNote extends StatelessWidget {
  const SideNote(this.text, {super.key, this.alert = false});

  final String text;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final color = alert ? AppColors.alert : AppColors.ink;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.alt,
        border: Border(left: BorderSide(color: color, width: 6)),
      ),
      child: Text(text, style: AppText.body(14, FontWeight.w600, color: color, height: 1.3)),
    );
  }
}

/// La imagen de [url]: de internet o, en la demo, del archivo del celular.
ImageProvider? attachmentImage(String url) {
  if (url.startsWith('http')) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    const extensions = ['.jpg', '.jpeg', '.png'];
    return extensions.any(path.endsWith) ? NetworkImage(url) : null;
  }
  final file = File(url);
  return file.existsSync() ? FileImage(file) : null;
}

/// El nombre del archivo al final de una dirección.
String attachmentName(String url) {
  final segments = url.split(RegExp(r'[/\\]')).where((s) => s.isNotEmpty);
  return segments.isEmpty ? url : Uri.decodeComponent(segments.last);
}

/// Un adjunto ya enviado: una foto (se puede ver en grande), un enlace (se
/// puede copiar) o un pedido.
class AttachmentRow extends StatelessWidget {
  const AttachmentRow({
    super.key,
    required this.kind,
    required this.title,
    this.url,
    this.children = const [],
  });

  final EvidenceKind kind;
  final String title;
  final String? url;

  /// Fecha, estado y notas, debajo del título.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    final image = kind == EvidenceKind.photo && url != null ? attachmentImage(url) : null;
    final icon = Icon(
      switch (kind) {
        EvidenceKind.photo => Icons.image_outlined,
        EvidenceKind.link => Icons.link,
        EvidenceKind.order => Icons.receipt_long_outlined,
      },
      color: AppColors.ink,
    );

    Widget thumbnail = ChamferBox(
      color: AppColors.alt,
      padding: EdgeInsets.zero,
      cut: 10,
      child: SizedBox.square(
        dimension: 48,
        child: image == null
            ? icon
            : Image(image: image, fit: BoxFit.cover, errorBuilder: (_, _, _) => icon),
      ),
    );
    if (image != null) {
      thumbnail = Semantics(
        button: true,
        label: 'Ver la foto $title',
        excludeSemantics: true,
        child: InkWell(onTap: () => _showPhoto(context, image), child: thumbnail),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.rule, width: 2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          thumbnail,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(14.5, FontWeight.w600, height: 1.2),
                ),
                ...children,
              ],
            ),
          ),
          if (kind == EvidenceKind.link && url != null)
            IconButton(
              tooltip: 'Copiar enlace',
              icon: const Icon(Icons.copy, size: 20, color: AppColors.violet),
              onPressed: () => _copy(context, url),
            ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: url));
    messenger.showSnackBar(const SnackBar(content: Text('Enlace copiado.')));
  }

  static void _showPhoto(BuildContext context, ImageProvider image) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: InteractiveViewer(child: Image(image: image))),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
          ],
        ),
      ),
    );
  }
}

/// ENVÍAS → JIME REVISA → VALIDADA U OBSERVADA.
class ReviewSteps extends StatelessWidget {
  const ReviewSteps({super.key});

  static const _steps = ['1 ENVÍAS', '2 JIME REVISA', '3 VALIDADA U OBSERVADA'];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Pasos: envías, Jime revisa y queda validada u observada',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, step) in _steps.indexed) ...[
            if (index > 0) const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ColoredBox(
                    color: index == 0 ? AppColors.violet : AppColors.rule,
                    child: const SizedBox(height: 6),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    step,
                    style: AppText.mono(
                      11,
                      color: index == 0 ? AppColors.ink : AppColors.muted,
                      weight: index == 0 ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
