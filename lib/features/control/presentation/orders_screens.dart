/// «Más» → Pedidos: Jime busca cualquier pedido para registrar una devolución
/// o anular una venta registrada dos veces.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/async_page.dart';
import '../../../core/ui/cut_button.dart';
import '../../../core/ui/dialogs.dart';
import '../../../core/ui/error_panel.dart';
import '../../../core/ui/ficha.dart';
import '../../../core/ui/form_pieces.dart';
import '../../../core/ui/refreshable_page.dart';
import '../../../core/ui/skeleton_block.dart';
import '../../orders/domain/orders.dart';
import '../../orders/presentation/order_widgets.dart';
import '../application/control_providers.dart';
import '../domain/control_orders.dart';
import 'panel_widgets.dart';

class ControlOrdersScreen extends ConsumerStatefulWidget {
  const ControlOrdersScreen({super.key});

  @override
  ConsumerState<ControlOrdersScreen> createState() => _ControlOrdersScreenState();
}

class _ControlOrdersScreenState extends ConsumerState<ControlOrdersScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  int _pages = 1;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || text.trim() == _query) return;
      setState(() {
        _query = text.trim();
        _pages = 1;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      for (var page = 1; page <= _pages; page++)
        ref.watch(controlOrdersProvider((search: _query, page: page))),
    ];
    final orders = [for (final page in pages) ...?page.value?.items];
    final first = pages.first;
    final last = pages.last;
    final today = ref.watch(todayProvider)();

    return RefreshablePage(
      onRefresh: () {
        ref.invalidate(controlOrdersProvider);
        return ref.read(controlOrdersProvider((search: _query, page: 1)).future);
      },
      children: [
        BackLink('Más', onTap: () => context.go(AppRoutes.more)),
        const PageTitle('Pedidos'),
        const SizedBox(height: 4),
        const HintText('Abre un pedido para registrar una devolución o anular un duplicado.'),
        const SizedBox(height: 10),
        LabeledField(
          label: 'Buscar por número o cliente',
          controller: _search,
          hint: 'N-1046 o nombre',
          inputFormatters: [LengthLimitingTextInputFormatter(60)],
          onChanged: _onSearch,
        ),
        const SizedBox(height: 8),
        if (orders.isEmpty && first.isLoading)
          for (var i = 0; i < 3; i++) ...const [SizedBox(height: 8), SkeletonBlock(height: 70)]
        else if (orders.isEmpty && first.hasError)
          ErrorPanel(
            message: errorMessage(first.error!),
            onRetry: () => ref.invalidate(controlOrdersProvider),
          )
        else if (orders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              _query.isEmpty ? 'Todavía no hay pedidos.' : 'Ningún pedido con «$_query».',
              style: AppText.body(15, FontWeight.w400, color: AppColors.muted),
            ),
          )
        else ...[
          for (final order in orders)
            _ControlOrderRow(
              order,
              today: today,
              onTap: () => context.go(AppRoutes.moreOrder(order.order.id)),
            ),
          if (last.value?.hasMore ?? false) ...[
            const SizedBox(height: 12),
            CutButton(
              label: 'Ver pedidos anteriores',
              height: 48,
              fontSize: 17,
              color: AppColors.ink,
              onPressed: () => setState(() => _pages++),
            ),
          ],
        ],
      ],
    );
  }
}

/// «Ailén» o «Tienda web».
String _soldBy(ControlOrderSummary order) => order.sellerName ?? 'Tienda web';

class _ControlOrderRow extends StatelessWidget {
  const _ControlOrderRow(this.row, {required this.today, required this.onTap});

  final ControlOrderSummary row;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final order = row.order;
    return MergeSemantics(
      child: InkWell(
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
                  children: [
                    Text(
                      '${order.number}  ${shortDate(order.createdAt, today)} · ${_soldBy(row)}',
                      style: AppText.mono(11.5, color: AppColors.muted),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      order.customerName,
                      style: AppText.body(15.5, FontWeight.w600, height: 1.2),
                    ),
                    Text(
                      order.itemsLabel,
                      style: AppText.body(13, FontWeight.w400, color: AppColors.muted),
                    ),
                    const SizedBox(height: 3),
                    OrderStatusMark(order.status),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(order.total.format(), style: AppText.display(17)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class ControlOrderScreen extends StatelessWidget {
  const ControlOrderScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return AsyncPage(
      provider: controlOrderProvider(orderId),
      header: [BackLink('Pedidos', onTap: () => context.go(AppRoutes.moreOrders))],
      builder: (context, ref, order) => [_ControlOrderBody(order)],
    );
  }
}

class _ControlOrderBody extends ConsumerWidget {
  const _ControlOrderBody(this.order);

  final ControlOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = order.detail;
    final summary = detail.summary;
    final payment = detail.payment;
    final today = ref.watch(todayProvider)();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${summary.number} · ${longDate(summary.createdAt, today)}'.toUpperCase(),
          style: AppText.mono(12, color: AppColors.muted),
        ),
        const SizedBox(height: 2),
        Text(summary.customerName, style: AppText.display(26, height: 1.15)),
        const SizedBox(height: 6),
        Align(alignment: Alignment.centerLeft, child: OrderStatusMark(summary.status)),
        if (order.voidReason != null) ...[
          const SizedBox(height: 8),
          HintText('Motivo: ${order.voidReason}'),
        ],
        if (order.duplicateOfNumber != null) ...[
          const SizedBox(height: 8),
          HintText('Anulado porque duplica el pedido ${order.duplicateOfNumber}.'),
        ],
        const SizedBox(height: 12),
        const SectionHeader('Productos'),
        for (final line in detail.lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line.itemCode, style: AppText.mono(11, color: AppColors.muted)),
                      Text(line.name, style: AppText.body(15, FontWeight.w600, height: 1.2)),
                      Text(
                        '${line.quantity} × ${line.unitPrice.formatInline()} · '
                        '${line.priceType.label}',
                        style: AppText.body(13, FontWeight.w400, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(line.total.format(), style: AppText.display(16)),
              ],
            ),
          ),
        LeaderRow(
          'Total',
          summary.total.format(),
          labelStyle: AppText.body(17, FontWeight.w700),
          valueStyle: AppText.mono(17, weight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        const SectionHeader('Pago'),
        LeaderRow('Método', summary.paymentMethod.label),
        if (payment != null) LeaderRow('Cobro', _paymentStatus(payment.status)),
        if (payment?.reference != null) LeaderRow('Referencia', payment!.reference!),
        const SizedBox(height: 12),
        const SectionHeader('Venta y entrega'),
        LeaderRow('La registró', order.sellerName ?? 'Tienda web'),
        LeaderRow('Llegó por', detail.origin.label),
        LeaderRow('Entrega', detail.deliveryType.label),
        if (detail.promisedAt != null)
          LeaderRow('Acordada', longDate(detail.promisedAt!, today)),
        if (detail.customerPhone != null) LeaderRow('WhatsApp', detail.customerPhone!),
        if (order.canReturn) ...[
          const SizedBox(height: 14),
          CutButton(
            label: 'Registrar devolución',
            color: AppColors.ink,
            onPressed: () => _return(context, ref),
          ),
        ],
        if (order.canMarkDuplicate) ...[
          const SizedBox(height: 10),
          Center(
            child: TextLink(
              'Es un duplicado',
              color: AppColors.ink,
              onTap: () => _duplicate(context, ref),
            ),
          ),
        ],
        if (!order.canReturn && !order.canMarkDuplicate) ...[
          const SizedBox(height: 12),
          const HintText('Este pedido ya no admite cambios desde aquí.'),
        ],
      ],
    );
  }

  static String _paymentStatus(PaymentStatus status) => switch (status) {
        PaymentStatus.pending => 'Sin pagar',
        PaymentStatus.submitted => 'Por confirmar',
        PaymentStatus.confirmed => 'Confirmado',
        PaymentStatus.rejected => 'Rechazado',
        PaymentStatus.reversed => 'Revertido',
      };

  Future<void> _return(BuildContext context, WidgetRef ref) async {
    final delivered = order.detail.summary.status == OrderStatus.delivered;
    final confirmed = order.detail.payment?.status == PaymentStatus.confirmed;
    final reason = await askReason(
      context,
      title: '¿Registrar la devolución?',
      label: 'Motivo',
      action: 'Registrar devolución',
      destructive: true,
      body: [
        confirmed
            ? 'El cobro se revierte y la comisión se descuenta.'
            : 'El cobro sin confirmar queda rechazado.',
        delivered
            ? 'Los productos vuelven al stock.'
            : 'Los productos vuelven a estar disponibles.',
        'No se puede deshacer.',
      ].join(' '),
    );
    if (reason == null || !context.mounted) return;
    await runPanelAction(
      context,
      () => ref
          .read(reviewRepositoryProvider)
          .returnOrder(order.detail.summary.id, reason: reason),
      success: 'Devolución registrada.',
    );
  }

  Future<void> _duplicate(BuildContext context, WidgetRef ref) async {
    final summary = order.detail.summary;
    final original = await showModalBottomSheet<ControlOrderSummary>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(),
      builder: (_) => _OriginalPicker(exclude: summary.id, customer: summary.customerName),
    );
    if (original == null || !context.mounted) return;
    final ok = await confirmAction(
      context,
      title: '¿Anular ${summary.number}?',
      body: 'Queda anulado como duplicado de ${original.order.number} '
          '(${original.order.customerName}, ${original.order.total.formatInline()}). '
          'No se puede deshacer.',
      action: 'Anular',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await runPanelAction(
      context,
      () => ref
          .read(reviewRepositoryProvider)
          .markDuplicate(summary.id, originalOrderId: original.order.id),
      success: '${summary.number} anulado como duplicado.',
    );
  }
}

/// El pedido original: arranca buscando al mismo cliente.
class _OriginalPicker extends ConsumerStatefulWidget {
  const _OriginalPicker({required this.exclude, required this.customer});

  final String exclude;
  final String customer;

  @override
  ConsumerState<_OriginalPicker> createState() => _OriginalPickerState();
}

class _OriginalPickerState extends ConsumerState<_OriginalPicker> {
  late final _search = TextEditingController(text: widget.customer);
  late String _query = widget.customer.trim();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(controlOrdersProvider((search: _query, page: 1)));
    final today = ref.watch(todayProvider)();
    // Uno anulado o devuelto no puede ser el original.
    final candidates = [
      for (final row in page.value?.items ?? const <ControlOrderSummary>[])
        if (row.order.id != widget.exclude &&
            !const {OrderStatus.cancelled, OrderStatus.expired, OrderStatus.returned}
                .contains(row.order.status))
          row,
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          children: [
            Text('¿Cuál es el original?', style: AppText.display(22)),
            const SizedBox(height: 10),
            LabeledField(
              label: 'Buscar el original',
              controller: _search,
              inputFormatters: [LengthLimitingTextInputFormatter(60)],
              onChanged: (text) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), () {
                  if (mounted) setState(() => _query = text.trim());
                });
              },
            ),
            const SizedBox(height: 8),
            if (page.isLoading && candidates.isEmpty)
              const SkeletonBlock(height: 70)
            else if (page.hasError)
              ErrorPanel(
                message: errorMessage(page.error!),
                onRetry: () => ref.invalidate(controlOrdersProvider),
              )
            else if (candidates.isEmpty)
              const HintText('No hay otro pedido con esa búsqueda.'),
            for (final row in candidates)
              _ControlOrderRow(row, today: today, onTap: () => Navigator.pop(context, row)),
          ],
        ),
      ),
    );
  }
}
