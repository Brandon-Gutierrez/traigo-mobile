import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/error_panel.dart';
import '../../../core/ui/ficha.dart';
import '../../../core/ui/refreshable_page.dart';
import '../../../core/ui/skeleton_block.dart';
import '../application/team_providers.dart';
import '../domain/kpi.dart';
import '../domain/my_week.dart';
import 'week_widgets.dart';

/// El botón central de Contenido y Sistemas: solo lo que Jime todavía no
/// valida (indicadores y, en Sistemas, entregas).
class EvidenceScreen extends ConsumerWidget {
  const EvidenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(myWeekProvider(null));

    return RefreshablePage(
      onRefresh: () {
        ref.invalidate(myWeekProvider(null));
        return ref.read(myWeekProvider(null).future);
      },
      children: [
        Text('Evidencia', style: AppText.display(30, height: 1.1)),
        const SizedBox(height: 4),
        ...week.when(
          data: (data) => _content(context, data),
          loading: () => const [
            SizedBox(height: 8),
            SkeletonBlock(height: 80),
            SizedBox(height: 12),
            SkeletonBlock(height: 80),
          ],
          error: (error, _) => [
            const SizedBox(height: 8),
            ErrorPanel(
              message: errorMessage(error),
              onRetry: () => ref.invalidate(myWeekProvider(null)),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _content(BuildContext context, MyWeek week) {
    final muted = AppText.body(15, FontWeight.w400, color: AppColors.muted, height: 1.35);
    final indicators = week.awaitingEvidence;
    final deliverables = week.openDeliverables;

    return [
      Text(
        'LO QUE JIME TODAVÍA NO VALIDA · ${week.week.label.toUpperCase()}',
        style: AppText.mono(12, color: AppColors.muted),
      ),
      const SizedBox(height: 14),
      if (!week.acceptsEvidence) ...[
        const SideNote('Esta semana ya se cerró: no se puede subir más evidencia.'),
        const SizedBox(height: 12),
      ],
      if (indicators.isEmpty && deliverables.isEmpty)
        Text('Toda tu evidencia está validada.', style: muted),
      if (indicators.isNotEmpty) ...[
        const SectionHeader('Indicadores'),
        for (final item in indicators)
          _PendingIndicator(
            item,
            onTap: () => context.go(
              AppRoutes.indicator(AppRoutes.evidence, item.indicator.id),
            ),
          ),
      ],
      if (deliverables.isNotEmpty) ...[
        const SizedBox(height: 14),
        const SectionHeader('Entregas técnicas'),
        for (final deliverable in deliverables)
          DeliverableRow(
            deliverable,
            onTap: () => context.go(
              AppRoutes.deliverable(AppRoutes.evidence, deliverable.id),
            ),
          ),
      ],
      if (week.weekNumber > 1) ...[
        const SizedBox(height: 12),
        Text(
          '¿Te faltó algo de una semana anterior? Súbelo desde «Mi semana».',
          style: muted,
        ),
      ],
      const SizedBox(height: 4),
      Align(
        alignment: Alignment.centerLeft,
        child: TextLink('Ver mi semana', onTap: () => context.go(AppRoutes.week)),
      ),
    ];
  }
}

class _PendingIndicator extends StatelessWidget {
  const _PendingIndicator(this.item, {required this.onTap});

  final WeekIndicator item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (kind, text) = evidenceMark(item);
    final observation = item.indicator.evidence == EvidenceStatus.observed
        ? item.evidence.firstOrNull?.reviewNote
        : null;
    return OpenRow(
      onTap: onTap,
      children: [
        Text(item.indicator.name, style: AppText.body(15, FontWeight.w600, height: 1.2)),
        const SizedBox(height: 3),
        StatusMark(kind, text),
        if (observation != null) ...[
          const SizedBox(height: 2),
          Text(
            observation,
            style: AppText.body(12.5, FontWeight.w600, color: AppColors.alert, height: 1.3),
          ),
        ],
      ],
    );
  }
}
