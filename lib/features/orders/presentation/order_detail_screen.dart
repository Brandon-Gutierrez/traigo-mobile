import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/chamfer.dart';
import '../../../core/ui/cut_button.dart';
import '../../../core/ui/error_panel.dart';
import '../../../core/ui/ficha.dart';
import '../../../core/ui/form_pieces.dart';
import '../../../core/ui/refreshable_page.dart';
import '../../../core/ui/skeleton_block.dart';
import '../../catalog/presentation/product_art.dart';
import '../application/orders_providers.dart';
import '../application/proof_picker.dart';
import '../domain/orders.dart';
import 'commission_line.dart';
import 'order_widgets.dart';
import 'proof_sheet.dart';

/// El detalle de un pedido: avance, productos, pago y comprobante, entrega y
/// comisión.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderDetailProvider(orderId));

    return RefreshablePage(
      onRefresh: () {
        ref.invalidate(orderDetailProvider(orderId));
        return ref.read(orderDetailProvider(orderId).future);
      },
      children: [
        BackLink('Mis pedidos', onTap: () => context.go(AppRoutes.orders)),
        ...order.when(
          data: (data) => [_OrderBody(data)],
          loading: () => const [
            SkeletonBlock(height: 90),
            SizedBox(height: 14),
            SkeletonBlock(height: 140),
          ],
          error: (error, _) => [
            ErrorPanel(
              message: errorMessage(error),
              onRetry: () => ref.invalidate(orderDetailProvider(orderId)),
            ),
          ],
        ),
      ],
    );
  }
}

class _OrderBody extends ConsumerWidget {
  const _OrderBody(this.order);

  final OrderDetail order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = order.summary;
    final today = ref.watch(todayProvider)();
    final commission = order.commission;
    final address = order.shippingAddress;
    final closed = const {
      OrderStatus.cancelled,
      OrderStatus.expired,
      OrderStatus.returned,
    }.contains(summary.status);

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
        if (!closed) _Progress(order.timeline),
        const SizedBox(height: 14),
        const SectionHeader('Productos'),
        for (final line in order.lines) _ProductLine(line),
        const ColoredBox(color: AppColors.ink, child: SizedBox(height: 2)),
        LeaderRow(
          'Total',
          summary.total.format(),
          labelStyle: AppText.body(17, FontWeight.w700),
          valueStyle: AppText.mono(17, weight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        _Payment(order, today),
        const SizedBox(height: 14),
        const SectionHeader('Entrega'),
        LeaderRow('Tipo', order.deliveryType.label),
        LeaderRow('Llegó por', order.origin.label),
        if (order.customerPhone != null) LeaderRow('WhatsApp', order.customerPhone!),
        if (address != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(address, style: AppText.body(15, FontWeight.w400)),
          ),
        if (commission != null) ...[
          const SizedBox(height: 14),
          const SectionHeader('Tu comisión'),
          CommissionLine(
            label: switch (commission.status) {
              CommissionStatus.pending => 'Pendiente hasta que se cobre',
              CommissionStatus.earned => 'Ganada con este pedido',
              CommissionStatus.cancelled => 'Anulada',
            },
            amount: commission.amount,
          ),
        ],
        if (order.canCancel) ...[
          const SizedBox(height: 12),
          Center(
            child: TextLink(
              'Cancelar pedido',
              color: AppColors.ink,
              onTap: () => _confirmCancel(context, ref),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _CancelDialog(),
    );
    if (reason == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(ordersRepositoryProvider).cancel(
            order.summary.id,
            reason: reason.isEmpty ? null : reason,
          );
      messenger.showSnackBar(
        SnackBar(content: Text('Pedido ${order.summary.number} cancelado.')),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
    if (context.mounted) refreshSalesData(ref);
  }
}

/// Devuelve el motivo (puede ir vacío) o `null` si se arrepiente.
class _CancelDialog extends StatefulWidget {
  const _CancelDialog();

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('¿Cancelar este pedido?'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Los productos vuelven a estar disponibles. No se puede deshacer.'),
          const SizedBox(height: 12),
          LabeledField(label: 'Motivo (opcional)', controller: _reason),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Volver')),
        TextButton(
          onPressed: () => Navigator.pop(context, _reason.text.trim()),
          style: TextButton.styleFrom(foregroundColor: AppColors.alert),
          child: const Text('Cancelar pedido'),
        ),
      ],
    );
  }
}

/// Registrado → pago confirmado → listo → entregado.
class _Progress extends StatelessWidget {
  const _Progress(this.timeline);

  final List<TimelineStep> timeline;

  static String _label(OrderStatus status) => switch (status) {
        OrderStatus.pendingPayment => 'REGISTRADO',
        OrderStatus.paid => 'PAGO CONFIRMADO',
        OrderStatus.ready => 'LISTO',
        OrderStatus.delivered => 'ENTREGADO',
        _ => status.label.toUpperCase(),
      };

  @override
  Widget build(BuildContext context) {
    final done = timeline.where((s) => s.at != null).map((s) => _label(s.status));
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Semantics(
        label: 'Avance: ${done.join(', ').toLowerCase()}',
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (index, step) in timeline.indexed) ...[
              if (index > 0) const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ColoredBox(
                      color: step.at == null ? AppColors.rule : AppColors.violet,
                      child: const SizedBox(height: 6),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _label(step.status),
                      style: AppText.mono(
                        10.5,
                        color: step.at == null ? AppColors.muted : AppColors.ink,
                        weight: step.at == null ? FontWeight.w400 : FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductLine extends StatelessWidget {
  const _ProductLine(this.line);

  final OrderLine line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          ProductTile(category: line.category, imageUrl: line.imageUrl, size: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.itemCode, style: AppText.mono(11, color: AppColors.muted)),
                Text(line.name, style: AppText.body(15, FontWeight.w600, height: 1.2)),
                Text(
                  '${line.quantity} × ${line.unitPrice.formatInline()} · ${line.priceType.label}',
                  style: AppText.body(13, FontWeight.w400, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(line.total.format(), style: AppText.display(17)),
        ],
      ),
    );
  }
}

class _Payment extends ConsumerWidget {
  const _Payment(this.order, this.today);

  final OrderDetail order;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final method = order.summary.paymentMethod;
    final payment = order.payment;
    final proofUrl = payment?.proofUrl;
    final muted = AppText.body(13, FontWeight.w400, color: AppColors.muted, height: 1.3);

    final String? note;
    if (payment?.status == PaymentStatus.confirmed) {
      note = 'Jime confirmó el pago.';
    } else if (method == PaymentMethod.cash && order.canCancel) {
      note = 'El efectivo se confirma cuando Jime valida la caja del día.';
    } else {
      note = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Pago'),
        LeaderRow('Método', method.label),
        if (payment?.reference != null) LeaderRow('Referencia', payment!.reference!),
        if (payment?.status == PaymentStatus.rejected) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppColors.alt,
              border: Border(left: BorderSide(color: AppColors.alert, width: 6)),
            ),
            child: Text(
              'Jime rechazó el comprobante'
              '${payment!.rejectReason == null ? '.' : ': ${payment.rejectReason}'}',
              style: AppText.body(14, FontWeight.w600, color: AppColors.alert),
            ),
          ),
        ],
        if (proofUrl != null) ...[
          if (payment?.submittedAt != null)
            LeaderRow('Comprobante', 'Subido ${longDate(payment!.submittedAt!, today)}'),
          const SizedBox(height: 6),
          _ProofRow(
            url: proofUrl,
            waiting: order.summary.status == OrderStatus.paymentReview,
            onChange: order.canUploadProof ? () => _attach(context, ref) : null,
          ),
        ],
        if (order.canUploadProof &&
            (proofUrl == null || payment?.status == PaymentStatus.rejected)) ...[
          const SizedBox(height: 10),
          CutButton(label: 'Subir comprobante', onPressed: () => _attach(context, ref)),
        ],
        if (note != null) ...[const SizedBox(height: 4), Text(note, style: muted)],
      ],
    );
  }

  Future<void> _attach(BuildContext context, WidgetRef ref) async {
    final source = await chooseProofSource(context);
    if (source == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final UploadFile? file;
    try {
      file = await ref.read(proofPickerProvider).pick(source);
    } on PlatformException {
      messenger.showSnackBar(SnackBar(
        content: Text(
          source == ProofSource.camera
              ? 'No se pudo abrir la cámara. Revisa los permisos de la app.'
              : 'No se pudo abrir la galería. Revisa los permisos de la app.',
        ),
      ));
      return;
    }
    if (file == null || !context.mounted) return;
    final updated = await reviewAndSendProof(context, orderId: order.summary.id, file: file);
    if (updated == null || !context.mounted) return;
    refreshSalesData(ref);
    messenger.showSnackBar(
      const SnackBar(content: Text('Comprobante enviado. Jime lo va a revisar.')),
    );
  }
}

class _ProofRow extends StatelessWidget {
  const _ProofRow({required this.url, required this.waiting, this.onChange});

  final String url;
  final bool waiting;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final filename = Uri.tryParse(url)?.pathSegments.lastOrNull ?? 'comprobante';
    const icon = Icon(Icons.image_outlined, color: AppColors.ink);
    final onChange = this.onChange;
    return Row(
      children: [
        ChamferBox(
          color: AppColors.alt,
          padding: EdgeInsets.zero,
          cut: 10,
          child: SizedBox.square(
            dimension: 56,
            child: url.startsWith('http')
                ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => icon)
                : icon,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(filename, style: AppText.body(14, FontWeight.w600)),
              if (waiting)
                Text(
                  'Jime lo confirma y el pedido pasa a «Pagado».',
                  style: AppText.body(12.5, FontWeight.w400, color: AppColors.muted),
                ),
            ],
          ),
        ),
        if (onChange != null) TextLink('Cambiar', onTap: onChange),
      ],
    );
  }
}
