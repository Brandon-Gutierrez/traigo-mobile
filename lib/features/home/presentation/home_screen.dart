import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/cut_button.dart';
import '../../../core/ui/error_panel.dart';
import '../../../core/ui/ficha.dart';
import '../../../core/ui/refreshable_page.dart';
import '../../../core/ui/rise_in.dart';
import '../../../core/ui/skeleton_block.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/auth.dart';
import '../../auth/presentation/account_header.dart';
import '../../team/domain/bonus.dart';
import '../../team/domain/kpi.dart';
import '../../team/presentation/week_block.dart';
import '../../team/presentation/week_widgets.dart' show OpenRow;
import '../../warehouse/application/warehouse_providers.dart';
import '../../warehouse/presentation/dispatches_screen.dart' show dispatchSummary;
import '../application/home_providers.dart';
import '../domain/home.dart';

/// Inicio del equipo: el bono de la semana, la acción principal del rol, mi
/// KPI y lo propio de cada puesto.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(sessionControllerProvider).value?.member;
    final home = ref.watch(teamHomeProvider);
    if (member == null) return const SizedBox.shrink();

    return RefreshablePage(
      onRefresh: () {
        ref.invalidate(teamHomeProvider);
        return ref.read(teamHomeProvider.future);
      },
      children: [
        AccountHeader(
          greeting: 'Hola, ${member.firstName}',
          detail: '${member.title} · ${member.code}',
        ),
        const SizedBox(height: 12),
        ...home.when(
          data: (data) => _content(context, member, data),
          loading: () => const [
            SkeletonBlock(height: 126),
            SizedBox(height: 12),
            SkeletonBlock(height: 58),
            SizedBox(height: 16),
            SkeletonBlock(height: 120),
          ],
          error: (error, _) => [
            ErrorPanel(
              message: errorMessage(error),
              onRetry: () => ref.invalidate(teamHomeProvider),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _content(BuildContext context, Member member, TeamHome home) {
    final (action, route) = switch (member.role) {
      MemberRole.seller || MemberRole.wholesale => ('+ Registrar venta', AppRoutes.sell),
      MemberRole.warehouse => ('Cierre de caja', AppRoutes.cash),
      _ => ('Subir evidencia', AppRoutes.evidence),
    };
    final commission = home.monthCommission;
    final cash = home.cashToday;
    final deliverables = home.kpi.deliverables;

    return [
      RiseIn(
        child: WeekBlock(
          title: 'Bono del equipo · ${home.week.label}',
          percent: home.percent,
          collected: home.collected,
          target: home.week.target,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        _nextStepNote(home),
        style: AppText.body(13.5, FontWeight.w400, color: AppColors.muted, height: 1.3),
      ),
      const SizedBox(height: 10),
      CutButton(label: action, onPressed: () => context.go(route)),
      const SizedBox(height: 14),
      RiseIn(
        delay: const Duration(milliseconds: 90),
        child: _MyWeek(home: home),
      ),
      if (member.role.canSell) ...[
        if (commission != null) ...[
          const SizedBox(height: 14),
          _MonthSection(commission),
        ],
        const SizedBox(height: 14),
        _TodaySales(home.todaySales),
      ],
      if (cash != null) ...[
        const SizedBox(height: 14),
        const _WarehouseSection(),
        const SizedBox(height: 14),
        _CashSection(cash),
      ],
      if (deliverables != null) ...[
        const SizedBox(height: 14),
        _DeliverablesSection(deliverables, onOpen: () => context.go(AppRoutes.week)),
      ],
      if (member.role == MemberRole.content || member.role == MemberRole.systems) ...[
        const SizedBox(height: 14),
        _PendingEvidence(home.kpi.awaitingEvidence),
      ],
    ];
  }

  /// Cuánto falta para el siguiente escalón del premio.
  static String _nextStepNote(TeamHome home) {
    final level = home.level;
    final next = BonusRules.nextLevel(level);
    if (next == null) return 'El equipo ya llega al premio superior (115 %).';

    final missing =
        (BonusRules.threshold(home.week.target, next) - home.collected).formatInline();
    return switch (next) {
      BonusLevel.partial => 'Faltan $missing para el primer premio (90 %).',
      BonusLevel.complete =>
        'El equipo ya llega al premio parcial. Faltan $missing para el completo (100 %).',
      _ => 'El equipo ya llega al premio completo. Faltan $missing para el superior (115 %).',
    };
  }
}

/// Mi KPI de la semana y lo que me toca del bono.
class _MyWeek extends StatelessWidget {
  const _MyWeek({required this.home});

  final TeamHome home;

  @override
  Widget build(BuildContext context) {
    final kpi = home.kpi;
    // Antes del 100 % se muestra la meta; después, el escalón ya alcanzado.
    final reached = home.percent >= 100;
    final level = reached ? home.level : BonusLevel.complete;
    final shareLabel = reached
        ? 'Tu parte con el premio ${level.label.toLowerCase()}'
        : 'Tu parte si el equipo llega al 100 %';

    final closedReason = kpi.closedReason;
    final (kind, text) = switch (kpi.compliance) {
      Compliance.passes => (MarkKind.ok, 'Cumples tu mínimo'),
      // Cerrada por Jime ya no es «todavía»: quedó así.
      Compliance.fails when closedReason != null => (
          MarkKind.bad,
          'Jime cerró tu semana: no cumple',
        ),
      Compliance.fails => (MarkKind.bad, 'Todavía no llegas a tu mínimo'),
      Compliance.pending => (MarkKind.pending, _pendingReason(kpi)),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Tu semana',
          trailing: TextLink('Ver mi semana', onTap: () => context.go(AppRoutes.week)),
        ),
        LeaderRow('Tu KPI', '${kpi.scorePercent} %'),
        LeaderRow(
          'Mínimo para cobrar tu parte',
          '${kpi.minimumPercent} %',
          labelStyle: AppText.body(15, FontWeight.w400, color: AppColors.muted),
        ),
        LeaderRow(shareLabel, home.shareAt(level).format()),
        const SizedBox(height: 6),
        Align(alignment: Alignment.centerLeft, child: StatusMark(kind, text)),
        if (closedReason != null) ...[
          const SizedBox(height: 2),
          Text(
            'Motivo: $closedReason',
            style: AppText.body(12.5, FontWeight.w400, color: AppColors.muted),
          ),
        ],
      ],
    );
  }

  static String _pendingReason(MyKpi kpi) {
    final deliverables = kpi.deliverables;
    if (deliverables != null && !deliverables.complete) {
      return 'Pendiente: faltan entregas por validar';
    }
    return 'Pendiente: faltan valores por cargar';
  }
}

class _MonthSection extends StatelessWidget {
  const _MonthSection(this.commission);

  final MonthCommission commission;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Este mes'),
        LeaderRow(
          'Comisión del mes',
          commission.amount.formatFixed(),
          labelStyle: AppText.body(17, FontWeight.w700),
          valueStyle: AppText.mono(16, weight: FontWeight.w700, color: AppColors.violet),
        ),
        const SizedBox(height: 2),
        Text(
          'Se paga una vez al mes. Fecha de pago: ${commission.payNote ?? 'por definir'}.',
          style: AppText.body(12.5, FontWeight.w400, color: AppColors.muted),
        ),
      ],
    );
  }
}

class _TodaySales extends StatelessWidget {
  const _TodaySales(this.sales);

  final List<TodaySale> sales;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Ventas de hoy',
          trailing: TextLink('Ver todas', onTap: () => context.go(AppRoutes.orders)),
        ),
        if (sales.isEmpty)
          Text(
            'Hoy todavía no registras ventas. Toca «Registrar venta» para empezar.',
            style: AppText.body(15, FontWeight.w400, color: AppColors.muted, height: 1.35),
          )
        else
          for (final (index, sale) in sales.indexed)
            InkWell(
              onTap: () => context.go(AppRoutes.order(sale.id)),
              child: _SaleRow(sale, divided: index > 0),
            ),
      ],
    );
  }
}

class _SaleRow extends StatelessWidget {
  const _SaleRow(this.sale, {required this.divided});

  final TodaySale sale;
  final bool divided;

  static String _time(DateTime at) {
    final local = at.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: divided
          ? const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.rule, width: 2)),
            )
          : null,
      child: Row(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44),
            child: Text(_time(sale.createdAt), style: AppText.mono(12, color: AppColors.muted)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sale.itemsLabel, style: AppText.body(15, FontWeight.w600, height: 1.2)),
                const SizedBox(height: 1),
                Text(
                  '${sale.customerName} · ${sale.paymentMethod.label}',
                  style: AppText.body(13, FontWeight.w400, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(sale.total.format(), style: AppText.display(16)),
              // El % de comisión por producto todavía no está definido.
              Text('[% por definir]', style: AppText.mono(11, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CashSection extends StatelessWidget {
  const _CashSection(this.cash);

  final CashToday cash;

  @override
  Widget build(BuildContext context) {
    final kind = switch (cash.status) {
      CashStatus.validated => MarkKind.ok,
      CashStatus.observed => MarkKind.bad,
      CashStatus.open || CashStatus.sent => MarkKind.pending,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Caja de hoy'),
        LeaderRow(
          'Cobrado hoy',
          cash.collected.format(),
          labelStyle: AppText.body(17, FontWeight.w700),
          valueStyle: AppText.mono(16, weight: FontWeight.w700, color: AppColors.violet),
        ),
        LeaderRow('Pedidos pagados', '${cash.paidOrders}'),
        LeaderRow('Pedidos por cobrar', '${cash.pendingOrders}'),
        const SizedBox(height: 6),
        Align(alignment: Alignment.centerLeft, child: StatusMark(kind, cash.status.label)),
        if (cash.pendingDays > 0) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: StatusMark(
              MarkKind.bad,
              cash.pendingDays == 1
                  ? 'Falta cerrar 1 día anterior'
                  : 'Faltan cerrar ${cash.pendingDays} días anteriores',
            ),
          ),
        ],
      ],
    );
  }
}

/// Despachos y stock, que no tienen pestaña propia.
class _WarehouseSection extends ConsumerWidget {
  const _WarehouseSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(dispatchQueueProvider);
    final dispatches = queue.value;
    final anyLate = dispatches?.any((d) => d.isLate) ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Almacén'),
        _OpenLine(
          title: 'Despachos',
          detail: dispatches != null
              ? dispatchSummary(dispatches)
              : (queue.hasError ? 'No se pudieron cargar' : 'Cargando…'),
          alert: anyLate,
          onTap: () => context.go(AppRoutes.dispatches),
        ),
        _OpenLine(
          title: 'Stock y conteos',
          detail: 'Ingresos, ajustes y conteo físico',
          onTap: () => context.go(AppRoutes.stock),
        ),
      ],
    );
  }
}

class _OpenLine extends StatelessWidget {
  const _OpenLine({
    required this.title,
    required this.detail,
    required this.onTap,
    this.alert = false,
  });

  final String title;
  final String detail;
  final VoidCallback onTap;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return OpenRow(
      onTap: onTap,
      children: [
        Text(title, style: AppText.body(16, FontWeight.w700)),
        Text(
          detail,
          style: AppText.body(
            13,
            alert ? FontWeight.w600 : FontWeight.w400,
            color: alert ? AppColors.alert : AppColors.muted,
          ),
        ),
      ],
    );
  }
}

class _DeliverablesSection extends StatelessWidget {
  const _DeliverablesSection(this.deliverables, {required this.onOpen});

  final DeliverableProgress deliverables;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Entregas técnicas', trailing: TextLink('Ver entregas', onTap: onOpen)),
        LeaderRow('Validadas', '${deliverables.approved} de ${deliverables.total}'),
        const SizedBox(height: 2),
        Text(
          deliverables.complete
              ? 'Tus entregas están completas.'
              : 'Hasta que estén todas validadas, tu bono queda pendiente.',
          style: AppText.body(12.5, FontWeight.w400, color: AppColors.muted),
        ),
      ],
    );
  }
}

/// Indicadores cuya evidencia falta, está en revisión o fue observada.
class _PendingEvidence extends StatelessWidget {
  const _PendingEvidence(this.indicators);

  final List<KpiIndicator> indicators;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Evidencia pendiente'),
        if (indicators.isEmpty)
          Text(
            'Toda tu evidencia está validada.',
            style: AppText.body(15, FontWeight.w400, color: AppColors.muted),
          )
        else
          for (final indicator in indicators)
            InkWell(
              onTap: () => context.go(
                AppRoutes.indicator(AppRoutes.evidence, indicator.id),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(indicator.name, style: AppText.body(15, FontWeight.w400)),
                    ),
                    const SizedBox(width: 10),
                    StatusMark(
                      indicator.evidence == EvidenceStatus.observed
                          ? MarkKind.bad
                          : MarkKind.pending,
                      indicator.evidence.label,
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
