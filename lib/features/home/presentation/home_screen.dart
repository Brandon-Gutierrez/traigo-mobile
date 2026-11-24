import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/ui/error_panel.dart';
import '../../../core/ui/hard_button.dart';
import '../../../core/ui/hard_card.dart';
import '../../../core/ui/rise_in.dart';
import '../../../core/ui/skeleton_block.dart';
import '../../auth/application/session_controller.dart';
import '../../orders/domain/orders.dart';
import '../application/home_providers.dart';
import '../domain/home.dart';

/// Inicio: cuánto ganó hoy, comisión del mes con la parte del fondo, y las
/// últimas ventas. Desliza hacia abajo para actualizar.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).value;
    final summary = ref.watch(homeSummaryProvider);

    Future<void> refresh() async {
      ref.invalidate(homeSummaryProvider);
      try {
        await ref.read(homeSummaryProvider.future);
      } catch (_) {
        // El error ya se muestra en pantalla con su botón de reintentar.
      }
    }

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.ink,
        backgroundColor: AppColors.card,
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
          children: [
            _Header(
              name: session?.seller.firstName ?? '',
              code: session?.seller.code ?? '',
            ),
            const SizedBox(height: 14),
            ...summary.when(
              data: (home) => [
                RiseIn(child: _TodayCard(today: home.today)),
                const SizedBox(height: 14),
                const _Actions(),
                const SizedBox(height: 14),
                RiseIn(
                  delay: const Duration(milliseconds: 120),
                  child: _MonthCard(home: home),
                ),
                const SizedBox(height: 14),
                RiseIn(
                  delay: const Duration(milliseconds: 180),
                  child: _RecentSales(orders: home.recentOrders),
                ),
              ],
              loading: () => const [
                SkeletonBlock(height: 122),
                SizedBox(height: 14),
                _Actions(),
                SizedBox(height: 14),
                SkeletonBlock(height: 196),
                SizedBox(height: 14),
                SkeletonBlock(height: 120),
              ],
              error: (error, _) => [
                ErrorPanel(
                  message: errorMessage(error),
                  onRetry: () => ref.invalidate(homeSummaryProvider),
                ),
                const SizedBox(height: 14),
                const _Actions(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.name, required this.code});

  final String name;
  final String code;

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Tendrás que ingresar otra vez con tu código y tu PIN.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: AppText.body(15, FontWeight.w700, color: AppColors.blue)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Cerrar sesión', style: AppText.body(15, FontWeight.w800, color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(sessionControllerProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hola, $name', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 3),
              Text(
                'Equipo de ventas · código $code',
                style: AppText.body(14, FontWeight.w500, color: AppColors.muted),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Cerrar sesión',
          onPressed: () => _confirmLogout(context, ref),
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            backgroundColor: AppColors.card,
            foregroundColor: AppColors.ink,
            shape: const RoundedRectangleBorder(
              side: BorderSide(color: AppColors.ink, width: 2),
            ),
          ),
          icon: const Icon(Icons.logout, size: 22),
        ),
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.today});

  final TodaySummary today;

  @override
  Widget build(BuildContext context) {
    final sales = today.salesCount == 1 ? '1 venta' : '${today.salesCount} ventas';
    return SizedBox(
      width: double.infinity,
      child: HardCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GANASTE HOY', style: AppText.label()),
            const SizedBox(height: 2),
            Text(
              // Las comisiones siempre llevan centavos: «Bs 90,00», no «Bs 90».
              today.commission.formatFixed(),
              style: AppText.money(46, FontWeight.w800, color: AppColors.ink, height: 1.05),
            ),
            const SizedBox(height: 2),
            Text(
              '$sales · ${today.soldTotal.format()} vendidos',
              style: AppText.body(15, FontWeight.w500, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Registrar venta (acción principal) y Merma (secundaria).
class _Actions extends StatelessWidget {
  const _Actions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: HardButton(
            label: '+ Registrar venta',
            onPressed: () => context.go(AppRoutes.sell),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: HardButton(
            label: 'Merma',
            primary: false,
            onPressed: () => context.go(AppRoutes.waste),
          ),
        ),
      ],
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.home});

  final HomeSummary home;

  @override
  Widget build(BuildContext context) {
    final fund = home.fund;
    final month = home.month;
    final prize = fund.prizeLabel;

    final fundText = fund.remaining.isZero
        ? 'Fondo del equipo: ${fund.current.format()} de ${fund.goal.format(symbol: false)}. '
            '¡El equipo alcanzó el hito!'
        : 'Fondo del equipo: ${fund.current.format()} de ${fund.goal.format(symbol: false)}. '
            'Faltan ${fund.remaining.format()} para el hito '
            '(${prize == null ? 'premio por definir' : 'premio: $prize'}).';

    return SizedBox(
      width: double.infinity,
      child: HardCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ESTE MES', style: AppText.label()),
            const SizedBox(height: 4),
            _MoneyRow(label: 'Mi comisión personal', value: month.personalCommission.formatFixed()),
            _MoneyRow(label: 'Mi parte del fondo del equipo', value: month.fundShare.formatFixed()),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.ink, width: 2)),
              ),
              child: _MoneyRow(
                label: 'Total estimado',
                value: month.estimatedTotal.formatFixed(),
                strong: true,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              // Espacio fijo tras «Bs» para que un monto no se parta entre líneas.
              fundText.replaceAll('Bs ', 'Bs '),
              style: AppText.body(13, FontWeight.w500, color: AppColors.muted, height: 1.3),
            ),
            const SizedBox(height: 6),
            _FundBar(progress: fund.progress),
            const SizedBox(height: 8),
            Text(
              'Pago de comisiones: ${home.payoutNote ?? 'por definir'}.',
              style: AppText.body(12, FontWeight.w500, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppText.body(strong ? 17 : 15, strong ? FontWeight.w800 : FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: AppText.money(
              strong ? 17 : 15,
              FontWeight.w800,
              color: strong ? AppColors.green : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de avance del fondo hacia el hito.
class _FundBar extends StatelessWidget {
  const _FundBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'Avance del fondo: ${(progress * 100).round()} por ciento',
      child: ExcludeSemantics(
        child: Container(
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(color: AppColors.ink, width: 2),
          ),
          alignment: Alignment.centerLeft,
          child: LayoutBuilder(
            builder: (context, box) => TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Container(
                width: box.maxWidth * value,
                decoration: BoxDecoration(
                  color: AppColors.orange,
                  border: value > 0 && value < 1
                      ? const Border(right: BorderSide(color: AppColors.ink, width: 2))
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentSales extends StatelessWidget {
  const _RecentSales({required this.orders});

  final List<OrderSummary> orders;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Ventas de hoy', style: Theme.of(context).textTheme.titleMedium),
            ),
            InkWell(
              onTap: () => context.go(AppRoutes.orders),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Text(
                  'Ver todas',
                  style: AppText.body(
                    14,
                    FontWeight.w700,
                    color: AppColors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (orders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Hoy todavía no registras ventas. Toca «Registrar venta» para empezar.',
              style: AppText.body(15, FontWeight.w500, color: AppColors.muted, height: 1.35),
            ),
          )
        else
          for (final order in orders) _SaleRow(order: order),
      ],
    );
  }
}

class _SaleRow extends StatelessWidget {
  const _SaleRow({required this.order});

  final OrderSummary order;

  static final _time = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    final commission = order.commission;
    final (color, decoration) = switch (commission.state) {
      CommissionState.approved => (AppColors.green, TextDecoration.none),
      CommissionState.pending => (AppColors.warn, TextDecoration.none),
      CommissionState.reverted => (AppColors.red, TextDecoration.lineThrough),
    };
    final payment = order.paymentMethod == PaymentMethod.qr ? 'QR' : 'Efectivo';

    return InkWell(
      onTap: () => context.go(AppRoutes.order(order.id)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        margin: const EdgeInsets.only(top: 4),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line, width: 2)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Text(
                _time.format(order.createdAt.toLocal()),
                style: AppText.body(13, FontWeight.w700, color: AppColors.muted),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.itemsLabel, style: AppText.body(15, FontWeight.w700, height: 1.15)),
                  const SizedBox(height: 1),
                  Text(
                    '${order.customerName} · ${order.total.format()} · $payment',
                    style: AppText.body(13, FontWeight.w500, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '+${commission.amount.formatFixed()}',
              style: AppText.money(16, FontWeight.w800, color: color)
                  .copyWith(decoration: decoration),
            ),
          ],
        ),
      ),
    );
  }
}
