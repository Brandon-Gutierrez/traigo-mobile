/// Cumplimiento de la semana y, para Jime, los indicadores de cada persona
/// para cargar sus valores reales.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/async_page.dart';
import '../../../core/ui/ficha.dart';
import '../../../core/ui/form_pieces.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/auth.dart';
import '../../team/domain/bonus.dart';
import '../../team/presentation/week_widgets.dart';
import '../application/control_providers.dart';
import '../domain/payouts.dart';
import 'panel_widgets.dart';

class ComplianceScreen extends StatelessWidget {
  const ComplianceScreen({super.key, this.weekNumber});

  /// `null`: la semana que falta cerrar.
  final int? weekNumber;

  static String _explanation(ComplianceRow row) {
    final registered = '${row.indicatorsLoaded} de ${row.indicatorsTotal} KPI cargados';
    if (row.closedReason != null) return 'Cerrado por Jime: ${row.closedReason}';
    final deliverables = row.deliverablesTotal;
    if (row.compliance != Compliance.passes &&
        deliverables != null &&
        row.deliverablesOnTime! < deliverables) {
      return '${row.deliverablesOnTime} de $deliverables entregas a tiempo · sin todas '
          'no hay primer bono';
    }
    final missing = row.missingPoints;
    if (missing != null && missing > 0) {
      return '$registered · le ${missing == 1 ? 'falta 1 punto' : 'faltan $missing puntos'}';
    }
    final right = row.compliance == Compliance.passes ? 'Sí' : 'No';
    return '$registered · derecho a bono: $right';
  }

  @override
  Widget build(BuildContext context) {
    return AsyncPage(
      provider: complianceProvider(weekNumber),
      header: [BackLink('Resumen', onTap: () => context.go(AppRoutes.summary))],
      builder: (context, ref, data) {
        final canLoad =
            ref.watch(sessionControllerProvider).value?.member.role == MemberRole.control;
        return [
          PageTitle('Cumplimiento', subtitle: data.week.label),
          WeekNav(
            shown: data.weekNumber,
            current: data.currentWeek,
            chosen: weekNumber,
            onShow: (week) => context.go(AppRoutes.complianceWeek(week)),
          ),
          const SizedBox(height: 8),
          for (final row in data.rows)
            InkWell(
              onTap: canLoad
                  ? () => context.go(
                        AppRoutes.complianceMember(row.id, weekNumber: data.weekNumber),
                      )
                  : null,
              child: _MemberRow(row, open: canLoad),
            ),
          const SizedBox(height: 8),
          HintText(
            'Cumple, No cumple o Pendiente (si falta cargar un KPI o validar una '
            'entrega). Los excesos de un indicador no compensan otro.'
            '${canLoad ? ' Toca a alguien para cargar sus valores.' : ''}',
          ),
        ];
      },
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow(this.row, {required this.open});

  final ComplianceRow row;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final (kind, text) = complianceMark(row.compliance);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.name, style: AppText.display(18)),
                    Text(row.title.toUpperCase(),
                        style: AppText.mono(11, color: AppColors.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${row.scorePercent ?? row.partialScorePercent} %',
                    style: AppText.display(22, weight: FontWeight.w800, height: 1),
                  ),
                  Text('mín. ${row.minimumPercent} %',
                      style: AppText.mono(11, color: AppColors.muted)),
                ],
              ),
              if (open) const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
          const SizedBox(height: 3),
          Align(alignment: Alignment.centerLeft, child: StatusMark(kind, text)),
          const SizedBox(height: 2),
          Text(
            ComplianceScreen._explanation(row),
            style: AppText.body(12.5, FontWeight.w400, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// Los indicadores de una persona: al tocar uno se carga su valor real.
class MemberWeekScreen extends StatelessWidget {
  const MemberWeekScreen({super.key, required this.memberId, this.weekNumber});

  final String memberId;
  final int? weekNumber;

  @override
  Widget build(BuildContext context) {
    return AsyncPage(
      provider: memberWeekProvider((id: memberId, week: weekNumber)),
      header: [
        BackLink(
          'Cumplimiento',
          onTap: () => context.go(AppRoutes.complianceWeek(weekNumber)),
        ),
      ],
      builder: (context, ref, week) {
        final name = ref
                .watch(complianceProvider(weekNumber))
                .value
                ?.rows
                .where((r) => r.id == memberId)
                .firstOrNull
                ?.name ??
            'Indicadores';
        return [
          PageTitle(name, size: 28, subtitle: week.week.label),
          const SizedBox(height: 10),
          const SectionHeader('Indicadores'),
          for (final item in week.indicators)
            OpenRow(
              onTap: () => context.go(
                AppRoutes.complianceIndicator(
                  memberId,
                  item.indicator.id,
                  weekNumber: weekNumber,
                ),
              ),
              children: [
                Text(item.indicator.name,
                    style: AppText.body(15, FontWeight.w600, height: 1.2)),
                Text(kpiProgress(item), style: AppText.mono(13, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Builder(builder: (context) {
                  final (kind, text) = evidenceMark(item);
                  return StatusMark(kind, text);
                }),
              ],
            ),
          if (week.deliverables.isNotEmpty) ...[
            const SizedBox(height: 14),
            const SectionHeader('Entregas técnicas'),
            for (final deliverable in week.deliverables)
              DeliverableRow(
                deliverable,
                onTap: () => context.go(AppRoutes.moreDeliverable(deliverable.id)),
              ),
          ],
        ];
      },
    );
  }
}
