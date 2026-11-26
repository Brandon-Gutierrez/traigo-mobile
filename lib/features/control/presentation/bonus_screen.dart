import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/async_page.dart';
import '../../../core/ui/chamfer.dart';
import '../../../core/ui/cut_button.dart';
import '../../../core/ui/dialogs.dart';
import '../../../core/ui/ficha.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/auth.dart';
import '../../orders/presentation/order_widgets.dart';
import '../../team/domain/bonus.dart';
import '../../team/presentation/week_widgets.dart' show complianceMark;
import '../application/control_providers.dart';
import '../domain/payouts.dart';
import 'panel_widgets.dart';

/// El bono de la semana: el nivel alcanzado y la parte de cada uno. Cuando
/// Dirección lo autoriza, Jime marca cada pago.
class BonusScreen extends StatelessWidget {
  const BonusScreen({super.key, this.weekNumber});

  /// `null`: la semana que falta pagar.
  final int? weekNumber;

  static String _statusLine(WeekClosingStatus status) => switch (status) {
        WeekClosingStatus.open => 'calculados, sin enviar',
        WeekClosingStatus.sent => 'pendiente de autorización',
        WeekClosingStatus.returned => 'devuelto a Jime',
        WeekClosingStatus.authorized => 'autorizado',
        WeekClosingStatus.paid => 'pagado',
      };

  @override
  Widget build(BuildContext context) {
    return AsyncPage(
      provider: weekBonusProvider(weekNumber),
      builder: (context, ref, bonus) {
        final role = ref.watch(sessionControllerProvider).value?.member.role;
        final percent = bonus.achievementPercent;
        final level = bonus.level == BonusLevel.none
            ? 'Sin premio · $percent %'
            : '${bonus.level.label} · $percent %';
        return [
          PageTitle('Bonos de la semana',
              subtitle: '${bonus.week.label} · ${_statusLine(bonus.status)}'),
          WeekNav(
            shown: bonus.weekNumber,
            current: bonus.currentWeek,
            chosen: weekNumber,
            pendingLabel: 'Ir a la que falta pagar',
            onShow: (week) => context.go(AppRoutes.bonusesWeek(week)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ChamferBox(
              color: AppColors.cyan,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NIVEL ALCANZADO', style: AppText.label(color: AppColors.ink)),
                  Text(level, style: AppText.display(28, weight: FontWeight.w800, height: 1.15)),
                  Text(
                    'Premio base ${bonus.week.basePrize.formatInline()} × factor '
                    '${bonus.releaseFactor.toStringAsFixed(2).replaceFirst('.', ',')}',
                    style: AppText.body(13.5, FontWeight.w400),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const SectionHeader('Reparto'),
          for (final row in bonus.members)
            _BonusRowView(
              bonus,
              row,
              canPay: role == MemberRole.control &&
                  (bonus.status == WeekClosingStatus.authorized ||
                      bonus.status == WeekClosingStatus.paid),
              key: ValueKey('bonus-${row.id}'),
            ),
          const ColoredBox(color: AppColors.ink, child: SizedBox(height: 3)),
          const SizedBox(height: 4),
          LeaderRow(
            'Total a pagar',
            bonus.payable.format(),
            labelStyle: AppText.body(17, FontWeight.w700),
            valueStyle: AppText.mono(17, weight: FontWeight.w700, color: AppColors.violet),
          ),
          LeaderRow(
            'No distribuido',
            bonus.unpaid.format(),
            labelStyle: AppText.body(15, FontWeight.w400, color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          const HintText(
            'Se paga solo con la autorización de Dirección. Lo que alguien no gana no '
            'se reparte a los demás.',
          ),
          if (role == MemberRole.management && bonus.status == WeekClosingStatus.sent) ...[
            const SizedBox(height: 12),
            CutButton(
              label: 'Revisar y autorizar',
              onPressed: () => context.go(
                AppRoutes.authorization('weekly_bonus', '${bonus.weekNumber}'),
              ),
            ),
          ],
        ];
      },
    );
  }
}

class _BonusRowView extends ConsumerWidget {
  const _BonusRowView(this.bonus, this.row, {required this.canPay, super.key});

  final WeekBonus bonus;
  final BonusRow row;
  final bool canPay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (kind, text) = complianceMark(row.compliance);
    final today = ref.watch(todayProvider)();
    final paidAt = row.paidAt;
    final String? aside = switch (row.compliance) {
      Compliance.fails => '${row.shareAmount.formatInline()} sin repartir',
      Compliance.pending => '${row.shareAmount.formatInline()} en espera',
      Compliance.passes => null,
    };
    final muted = AppText.body(12.5, FontWeight.w400, color: AppColors.muted);

    Future<void> pay() async {
      final ok = await confirmAction(
        context,
        title: '¿Marcar pagado a ${row.name}?',
        body: 'Queda registrado el pago de ${row.shareAmount.formatInline()}.',
        action: 'Marcar pagado',
      );
      if (!ok || !context.mounted) return;
      await runPanelAction(
        context,
        () => ref.read(payoutsRepositoryProvider).markBonusPaid(bonus.weekNumber, row.id),
        success: 'Pago de ${row.name} registrado.',
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
                    Text('${row.name} · ${(row.shareRate * 100).round()} %',
                        style: AppText.body(14.5, FontWeight.w600)),
                    StatusMark(kind, text),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                row.amount?.format() ?? '—',
                style: AppText.mono(15, weight: FontWeight.w700),
              ),
            ],
          ),
          if (aside != null) Text(aside, textAlign: TextAlign.right, style: muted),
          if (row.closedReason != null) Text('Cerrado por Jime: ${row.closedReason}', style: muted),
          if (paidAt != null)
            Text('Pagado ${longDate(paidAt, today)}', style: muted)
          else if (canPay && row.compliance == Compliance.passes)
            Align(
              alignment: Alignment.centerRight,
              child: TextLink('Marcar pagado', onTap: pay),
            ),
        ],
      ),
    );
  }
}
