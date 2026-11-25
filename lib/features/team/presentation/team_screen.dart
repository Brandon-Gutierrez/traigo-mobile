import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/chamfer.dart';
import '../../../core/ui/error_panel.dart';
import '../../../core/ui/ficha.dart';
import '../../../core/ui/refreshable_page.dart';
import '../../../core/ui/skeleton_block.dart';
import '../application/team_providers.dart';
import '../domain/bonus.dart';
import '../domain/team_week.dart';

/// «Equipo»: lo cobrado en la semana, los escalones del premio con mi parte y
/// todas las semanas de la campaña.
class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(teamWeekProvider);

    return RefreshablePage(
      onRefresh: () {
        ref.invalidate(teamWeekProvider);
        return ref.read(teamWeekProvider.future);
      },
      children: [
        Text('Bono del equipo', style: AppText.display(30, height: 1.1)),
        const SizedBox(height: 4),
        Text(
          'Se paga si el equipo cobra la meta y tú cumples tu KPI.',
          style: AppText.body(14, FontWeight.w400, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        ...team.when(
          data: _content,
          loading: () => const [
            SkeletonBlock(height: 120),
            SizedBox(height: 14),
            SkeletonBlock(height: 140),
          ],
          error: (error, _) => [
            ErrorPanel(
              message: errorMessage(error),
              onRetry: () => ref.invalidate(teamWeekProvider),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _content(TeamWeek team) {
    final reached = BonusRules.levelFor(team.collected, team.week.target);
    // Se resalta el escalón alcanzado; si no hay ninguno, la meta (100 %).
    final highlighted = reached == BonusLevel.none ? BonusLevel.complete : reached;
    final share = (team.myShareRate * 100).round();
    final myStatus = switch (team.myCompliance) {
      Compliance.passes => 'Ya cumples, vas en ${team.myPartialScorePercent} %.',
      Compliance.fails || Compliance.pending => 'Hoy vas en ${team.myPartialScorePercent} %.',
    };

    return [
      _CollectedCard(team),
      const SizedBox(height: 14),
      const SectionHeader('Escalones de premio'),
      _TierTable(
        header: ['NIVEL', 'VENTAS', 'EQUIPO', 'TU $share %'],
        rows: [
          for (final tier in team.tiers)
            (
              cells: [
                '${tier.thresholdPercent} % · ${tier.tier.label.toLowerCase()}',
                tier.salesNeeded.format(symbol: false),
                tier.fund.format(symbol: false),
                tier.myShare.format(symbol: false),
              ],
              highlighted: tier.tier == highlighted,
            ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        'Montos en bolivianos. Tu parte se paga solo si tu KPI llega a '
        '${team.myMinimumPercent} %. $myStatus Lo que alguien no gana no se '
        'reparte a los demás.',
        style: AppText.body(12.5, FontWeight.w400, color: AppColors.muted, height: 1.35),
      ),
      const SizedBox(height: 14),
      const SectionHeader('Todas las semanas'),
      for (final week in team.weeks) _WeekRow(week),
    ];
  }
}

class _CollectedCard extends StatelessWidget {
  const _CollectedCard(this.team);

  final TeamWeek team;

  @override
  Widget build(BuildContext context) {
    final percent = team.percent;
    final detail = 'de ${team.week.target.formatInline()} · $percent %';
    return ChamferBox(
      color: AppColors.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('COBRADO · ${team.week.label.toUpperCase()}',
              style: AppText.label(color: AppColors.ink)),
          const SizedBox(height: 2),
          Wrap(
            spacing: 10,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  team.collected.format(),
                  textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.1),
                  style: AppText.display(40, weight: FontWeight.w800, height: 1.1),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(detail, style: AppText.body(14, FontWeight.w400)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TickRuler(
            count: 20,
            filled: math.min(20, percent ~/ 5),
            semanticLabel: '$percent por ciento de la meta del equipo',
            on: AppColors.ink,
            off: AppColors.bg,
          ),
        ],
      ),
    );
  }
}

typedef _TierCells = ({List<String> cells, bool highlighted});

/// Cuatro columnas que se achican juntas si la letra no entra.
class _TierTable extends StatelessWidget {
  const _TierTable({required this.header, required this.rows});

  final List<String> header;
  final List<_TierCells> rows;

  static const _flex = [16, 9, 9, 8];

  Widget _row(List<Widget> cells) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final (index, cell) in cells.indexed) ...[
            if (index > 0) const SizedBox(width: 6),
            Expanded(
              flex: _flex[index],
              child: index == 0
                  ? cell
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: cell,
                    ),
            ),
          ],
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 4),
          child: _row([
            for (final title in header) Text(title, style: AppText.label()),
          ]),
        ),
        for (final row in rows)
          Semantics(
            label: '${row.cells[0]}: ventas ${row.cells[1]}, equipo ${row.cells[2]}, '
                'tu parte ${row.cells[3]}${row.highlighted ? ' (resaltado)' : ''}',
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: row.highlighted ? AppColors.alt : null,
                border: const Border(top: BorderSide(color: AppColors.rule, width: 2)),
              ),
              child: _row([
                Text(row.cells[0], style: AppText.body(13, FontWeight.w600, height: 1.2)),
                Text(row.cells[1], style: AppText.mono(12.5)),
                Text(row.cells[2], style: AppText.mono(12.5)),
                Text(
                  row.cells[3],
                  style: AppText.mono(12.5, weight: FontWeight.w700, color: AppColors.violet),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow(this.item);

  final CampaignWeek item;

  @override
  Widget build(BuildContext context) {
    final week = item.week;
    final weight = item.isCurrent ? FontWeight.w700 : FontWeight.w400;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      decoration: BoxDecoration(
        color: item.isCurrent ? AppColors.alt : null,
        border: const Border(top: BorderSide(color: AppColors.rule, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(week.label, style: AppText.body(14, weight))),
              if (item.isCurrent) Text('ACTUAL', style: AppText.label(color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 2),
          Wrap(
            spacing: 16,
            children: [
              Text('meta ${week.target.formatInline()}', style: AppText.mono(12.5)),
              Text('premio ${week.basePrize.formatInline()}', style: AppText.mono(12.5)),
            ],
          ),
        ],
      ),
    );
  }
}
