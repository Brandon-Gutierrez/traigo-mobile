import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/async_page.dart';
import '../../../core/ui/chamfer.dart';
import '../../../core/ui/dialogs.dart';
import '../../../core/ui/ficha.dart';
import '../../../core/ui/form_pieces.dart';
import '../../orders/presentation/order_widgets.dart';
import '../../team/domain/kpi.dart';
import '../../team/domain/my_week.dart';
import '../../team/presentation/week_widgets.dart';
import '../application/control_providers.dart';
import '../domain/review.dart';
import 'panel_widgets.dart';

/// Revisar la evidencia de un indicador y cargar su valor real.
class EvidenceReviewScreen extends StatelessWidget {
  const EvidenceReviewScreen({
    super.key,
    required this.resultId,
    required this.backLabel,
    required this.backRoute,
  });

  final String resultId;
  final String backLabel;
  final String backRoute;

  @override
  Widget build(BuildContext context) {
    return AsyncPage(
      provider: evidenceReviewProvider(resultId),
      header: [BackLink(backLabel, onTap: () => context.go(backRoute))],
      builder: (context, ref, review) => [
        _EvidenceBody(review, backRoute: backRoute, key: ValueKey(review.resultId)),
      ],
    );
  }
}

class _EvidenceBody extends ConsumerStatefulWidget {
  const _EvidenceBody(this.review, {required this.backRoute, super.key});

  final EvidenceReview review;
  final String backRoute;

  @override
  ConsumerState<_EvidenceBody> createState() => _EvidenceBodyState();
}

class _EvidenceBodyState extends ConsumerState<_EvidenceBody> {
  /// El valor que Jime va a cargar; `null` = sin cargar.
  late double? _actual = widget.review.indicator.actual;

  KpiIndicator get _indicator => widget.review.indicator;

  Future<void> _typeValue() async {
    final value = await showDialog<double>(
      context: context,
      builder: (_) => _ValueDialog(_actual),
    );
    if (value != null && mounted) setState(() => _actual = value);
  }

  Future<void> _validate() async {
    final ok = await runPanelAction(
      context,
      () => ref
          .read(reviewRepositoryProvider)
          .validateResult(widget.review.resultId, actual: _actual!),
      success: 'Guardado: ${widget.review.memberName}, «${_indicator.name}».',
    );
    if (ok && mounted) context.go(widget.backRoute);
  }

  Future<void> _observe() async {
    final reason = await askReason(
      context,
      title: '¿Pedir otra evidencia?',
      body: '${widget.review.memberName} ve tu nota y puede volver a subirla.',
      label: 'Qué falta',
      action: 'Observar',
    );
    if (reason == null || !mounted) return;
    final ok = await runPanelAction(
      context,
      () => ref
          .read(reviewRepositoryProvider)
          .observeResult(widget.review.resultId, note: reason),
      success: 'Evidencia observada.',
    );
    if (ok && mounted) context.go(widget.backRoute);
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final indicator = _indicator;
    final today = ref.watch(todayProvider)();
    final actual = _actual;
    final percent = review.unit == KpiUnit.percent;
    final progress = actual == null || indicator.target <= 0
        ? 0.0
        : (actual / indicator.target).clamp(0, 1).toDouble();
    final points = (indicator.weight * 100).round();
    final earned = progress * indicator.weight * 100;
    final waiting = indicator.evidence == EvidenceStatus.inReview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Revisar evidencia', style: AppText.display(26, height: 1.15)),
        const SizedBox(height: 10),
        ChamferBox(
          color: AppColors.alt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${review.memberName} · ${review.weekLabel}'.toUpperCase(),
                style: AppText.mono(11.5, color: AppColors.muted),
              ),
              const SizedBox(height: 2),
              Text(indicator.name, style: AppText.body(16, FontWeight.w600, height: 1.2)),
              Text(
                review.howVerified,
                style: AppText.body(13, FontWeight.w400, color: AppColors.muted, height: 1.3),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 16,
                children: [
                  Text(
                    'META ${kpiNumber(indicator.target)}${percent ? ' %' : ''}',
                    style: AppText.mono(12),
                  ),
                  Text('PESO $points %', style: AppText.mono(12)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionHeader('Lo que subió ${review.memberName}'),
        if (review.evidence.isEmpty)
          Text(
            'No subió evidencia. Igual puedes cargar el valor real.',
            style: AppText.body(14, FontWeight.w400, color: AppColors.muted),
          )
        else
          for (final evidence in review.evidence) _Submitted(evidence, today),
        const SizedBox(height: 14),
        const SectionHeader('Valor real alcanzado'),
        const SizedBox(height: 4),
        Row(
          children: [
            _StepButton(
              icon: Icons.remove,
              label: 'Bajar valor real',
              onTap: actual == null || actual < 1
                  ? null
                  : () => setState(() => _actual = actual - 1),
            ),
            const SizedBox(width: 10),
            Semantics(
              button: true,
              label: 'Valor real: ${actual == null ? 'sin cargar' : kpiNumber(actual)}. Escribir',
              excludeSemantics: true,
              onTap: _typeValue,
              child: InkWell(
                onTap: _typeValue,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      actual == null ? '—' : kpiNumber(actual),
                      key: const ValueKey('actual-value'),
                      style: AppText.display(34),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _StepButton(
              icon: Icons.add,
              label: 'Subir valor real',
              onTap: () => setState(() => _actual = (actual ?? 0) + 1),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Avance ${(progress * 100 + 1e-9).floor()} %\n'
                '${kpiNumber((earned * 10).floor() / 10)} de $points puntos',
                textAlign: TextAlign.right,
                style: AppText.body(13.5, FontWeight.w700, color: AppColors.violet, height: 1.25),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const HintText(
          'El avance no pasa de 100 %. Carga solo valores reales con respaldo; queda '
          'en el historial con tu nombre y la hora.',
        ),
        const SizedBox(height: 12),
        ActionButton(
          label: actual == null ? 'Carga el valor real' : 'Validar y guardar',
          onPressed: actual == null ? null : _validate,
        ),
        if (waiting)
          Center(
            child: TextLink('Observar y pedir otra evidencia',
                color: AppColors.ink, onTap: _observe),
          ),
      ],
    );
  }
}

class _Submitted extends StatelessWidget {
  const _Submitted(this.evidence, this.today);

  final Evidence evidence;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final muted = AppText.body(12.5, FontWeight.w400, color: AppColors.muted, height: 1.3);
    final (kind, text) = evidenceStatusMark(evidence.status);
    return AttachmentRow(
      kind: evidence.kind,
      url: evidence.url,
      title: evidenceTitle(evidence),
      children: [
        const SizedBox(height: 2),
        Text('Enviada ${longDate(evidence.submittedAt, today)}', style: muted),
        if (evidence.note != null) Text('«${evidence.note}»', style: muted),
        const SizedBox(height: 3),
        StatusMark(kind, text),
        if (evidence.reviewNote != null)
          Text(
            'Tu nota: ${evidence.reviewNote}',
            style: AppText.body(12.5, FontWeight.w600, color: AppColors.alert),
          ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.alt,
      shape: const Border(bottom: BorderSide(color: AppColors.ink, width: 3)),
      child: IconButton(
        tooltip: label,
        onPressed: onTap,
        icon: Icon(icon),
        color: AppColors.ink,
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      ),
    );
  }
}

class _ValueDialog extends StatefulWidget {
  const _ValueDialog(this.initial);

  final double? initial;

  @override
  State<_ValueDialog> createState() => _ValueDialogState();
}

class _ValueDialogState extends State<_ValueDialog> {
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    // Lo que ya había queda marcado: al escribir se reemplaza.
    final initial = widget.initial == null ? '' : kpiNumber(widget.initial!);
    _text = TextEditingController(text: initial)
      ..selection = TextSelection(baseOffset: 0, extentOffset: initial.length);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  double? get _value => double.tryParse(_text.text.replaceFirst(',', '.'));

  @override
  Widget build(BuildContext context) {
    final value = _value;
    return AlertDialog(
      title: const Text('Valor real'),
      scrollable: true,
      content: LabeledField(
        label: 'Valor alcanzado',
        controller: _text,
        autofocus: true,
        mono: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          LengthLimitingTextInputFormatter(8),
        ],
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Volver')),
        TextButton(
          onPressed: value == null ? null : () => Navigator.pop(context, value),
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}
