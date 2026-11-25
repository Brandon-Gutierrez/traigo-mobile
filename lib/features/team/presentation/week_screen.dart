import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/chamfer.dart';
import '../../../core/ui/error_panel.dart';
import '../../../core/ui/ficha.dart';
import '../../../core/ui/refreshable_page.dart';
import '../../../core/ui/skeleton_block.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/auth.dart';
import '../application/team_providers.dart';
import '../domain/kpi.dart';
import '../domain/my_week.dart';
import 'week_widgets.dart';

/// «Mi semana»: el puntaje, cada indicador con su evidencia y, para Sistemas,
/// las entregas técnicas. Se pueden revisar las semanas anteriores.
class WeekScreen extends ConsumerStatefulWidget {
  const WeekScreen({super.key});

  @override
  ConsumerState<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends ConsumerState<WeekScreen> {
  /// La semana que se está viendo; `null` es la actual.
  int? _weekNumber;

  @override
  Widget build(BuildContext context) {
    final member = ref.watch(sessionControllerProvider).value?.member;
    if (member == null) return const SizedBox.shrink();
    final week = ref.watch(myWeekProvider(_weekNumber));

    return RefreshablePage(
      onRefresh: () {
        ref.invalidate(myWeekProvider(_weekNumber));
        return ref.read(myWeekProvider(_weekNumber).future);
      },
      children: [
        Text('Mi semana', style: AppText.display(30, height: 1.1)),
        const SizedBox(height: 4),
        ...week.when(
          data: (data) => _content(member, data),
          loading: () => const [
            SizedBox(height: 8),
            SkeletonBlock(height: 130),
            SizedBox(height: 12),
            SkeletonBlock(height: 90),
          ],
          error: (error, _) => [
            const SizedBox(height: 8),
            ErrorPanel(
              message: errorMessage(error),
              onRetry: () => ref.invalidate(myWeekProvider(_weekNumber)),
            ),
            if (_weekNumber != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextLink('Volver a la semana actual', onTap: () => _show(null)),
              ),
          ],
        ),
      ],
    );
  }

  void _show(int? weekNumber) => setState(() => _weekNumber = weekNumber);

  List<Widget> _content(Member member, MyWeek week) {
    final muted = AppText.body(13, FontWeight.w400, color: AppColors.muted, height: 1.3);
    final closedReason = week.closedReason;
    final heading = [
      if (member.role == MemberRole.systems) member.name,
      week.week.label,
      if (week.countTargetFactor < 1)
        'metas al ${(week.countTargetFactor * 100).round()} % '
            '(${week.weekNumber == 1 ? 'primera semana' : 'semana corta'})',
    ].join(' · ').toUpperCase();

    void openIndicator(WeekIndicator item) => context.go(
          AppRoutes.indicator(AppRoutes.week, item.indicator.id, weekNumber: _weekNumber),
        );

    return [
      Text(heading, style: AppText.mono(12, color: AppColors.muted)),
      if (week.weekNumber > 1 || _weekNumber != null)
        Wrap(
          spacing: 20,
          children: [
            if (week.weekNumber > 1)
              TextLink('‹ Semana anterior', onTap: () => _show(week.weekNumber - 1)),
            if (_weekNumber != null)
              TextLink('Volver a la semana actual', onTap: () => _show(null)),
          ],
        ),
      const SizedBox(height: 12),
      _ScoreCard(week),
      const SizedBox(height: 8),
      Text(
        week.deliverables.isEmpty
            ? 'Con ${week.minimumPercent} % cobras tu parte del bono. Hacer más en un '
                'indicador no cubre lo que falta en otro.'
            : 'Cobras tu parte con ${week.minimumPercent} % de puntaje y tus '
                '${week.deliverables.length} entregas validadas a tiempo.',
        style: muted,
      ),
      if (closedReason != null) ...[
        const SizedBox(height: 8),
        SideNote('Jime cerró tu semana: no cumple. Motivo: $closedReason', alert: true),
      ] else if (!week.acceptsEvidence) ...[
        const SizedBox(height: 8),
        const SideNote('Esta semana ya se cerró: no se puede subir más evidencia.'),
      ],
      const SizedBox(height: 8),
      for (final item in week.indicators)
        _IndicatorBlock(
          item,
          key: ValueKey('indicator-${item.indicator.name}'),
          canUpload: week.acceptsEvidence && !item.isValidated,
          onOpen: () => openIndicator(item),
        ),
      if (week.deliverables.isNotEmpty) ...[
        const SizedBox(height: 14),
        const SectionHeader('Entregas técnicas'),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('Sin ellas no hay primer bono.', style: muted),
        ),
        for (final deliverable in week.deliverables)
          DeliverableRow(
            deliverable,
            onTap: () => context.go(AppRoutes.deliverable(
              AppRoutes.week,
              deliverable.id,
              weekNumber: _weekNumber,
            )),
          ),
      ],
    ];
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard(this.week);

  final MyWeek week;

  @override
  Widget build(BuildContext context) {
    final score = week.scorePercent ?? week.partialScorePercent;
    final (kind, text) = complianceMark(week.compliance);
    return ChamferBox(
      color: AppColors.alt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // El estado va a la derecha y baja si la letra es muy grande.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text('TU PUNTAJE', style: AppText.label()),
              StatusMark(kind, text),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '$score %',
            textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.1),
            style: AppText.display(48, weight: FontWeight.w800, height: 1.05),
          ),
          if (week.scorePercent == null)
            Text(
              'Avance con lo que Jime ya cargó.',
              style: AppText.body(13, FontWeight.w400, color: AppColors.muted),
            ),
          const SizedBox(height: 8),
          TickRuler(
            count: 20,
            filled: math.min(20, score ~/ 5),
            off: AppColors.bg,
            markAt: week.minimumPercent,
            semanticLabel: '$score por ciento de puntaje, mínimo ${week.minimumPercent}',
          ),
          const SizedBox(height: 8),
          Text('MÍNIMO ${week.minimumPercent} %', style: AppText.mono(11.5, color: AppColors.muted)),
        ],
      ),
    );
  }
}

/// Un indicador: avance, cómo se verifica y su evidencia.
class _IndicatorBlock extends StatelessWidget {
  const _IndicatorBlock(this.item, {super.key, required this.canUpload, required this.onOpen});

  final WeekIndicator item;
  final bool canUpload;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final indicator = item.indicator;
    final progress = (indicator.progress * 100 + 1e-9).floor();
    final weight = (indicator.weight * 100).round();
    final muted = AppText.body(12.5, FontWeight.w400, color: AppColors.muted, height: 1.3);
    final (kind, text) = evidenceMark(item);
    final observation = indicator.evidence == EvidenceStatus.observed
        ? item.evidence.firstOrNull?.reviewNote
        : null;

    final Widget? action;
    if (canUpload && indicator.evidence == EvidenceStatus.missing) {
      action = _SmallButton('Subir evidencia', onTap: onOpen);
    } else if (canUpload && indicator.evidence == EvidenceStatus.observed) {
      action = _SmallButton('Corregir', onTap: onOpen);
    } else if (item.evidence.isNotEmpty) {
      action = TextLink('Ver evidencia', onTap: onOpen);
    } else {
      action = null;
    }

    return Container(
      padding: const EdgeInsets.only(top: 9, bottom: 2),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.rule, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(indicator.name, style: AppText.body(15, FontWeight.w600, height: 1.2)),
              ),
              const SizedBox(width: 10),
              Text(kpiProgress(item), style: AppText.mono(14, weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TickRuler(
                  count: 10,
                  filled: progress ~/ 10,
                  height: 8,
                  semanticLabel: '$progress por ciento de la meta',
                ),
              ),
              const SizedBox(width: 10),
              Text('peso $weight %', style: AppText.mono(11, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 4),
          Text(item.howVerified, style: muted),
          if (observation != null) ...[
            const SizedBox(height: 4),
            Text(
              observation,
              style: AppText.body(12.5, FontWeight.w600, color: AppColors.alert, height: 1.3),
            ),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 46),
            child: Row(
              children: [
                Expanded(
                  child: Align(alignment: Alignment.centerLeft, child: StatusMark(kind, text)),
                ),
                if (action != null) ...[const SizedBox(width: 8), action],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón compacto con la esquina cortada, para dentro de una fila.
class _SmallButton extends StatelessWidget {
  const _SmallButton(this.label, {required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ClipPath(
          clipper: const ChamferClipper(cut: 10),
          child: Material(
            color: AppColors.violet,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Text(label, style: AppText.display(14, color: AppColors.bg)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
