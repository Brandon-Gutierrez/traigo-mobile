import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/cut_button.dart';
import '../../../core/ui/ficha.dart';
import '../../../core/ui/form_pieces.dart';
import '../../auth/presentation/auth_frame.dart' show FormError;
import '../application/orders_providers.dart';
import '../application/sale_draft.dart';
import '../domain/orders.dart';
import 'commission_line.dart';

/// Registrar venta, paso 2: cliente, cómo llegó, entrega y forma de pago.
class SaleCustomerScreen extends ConsumerStatefulWidget {
  const SaleCustomerScreen({super.key});

  @override
  ConsumerState<SaleCustomerScreen> createState() => _SaleCustomerScreenState();
}

class _SaleCustomerScreenState extends ConsumerState<SaleCustomerScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;

  bool _busy = false;
  String? _error;

  /// La venta quizá ya se registró: se ofrece revisar «Mis pedidos».
  bool _checkOrders = false;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(saleDraftProvider);
    _name = TextEditingController(text: draft.customerName);
    _phone = TextEditingController(text: draft.customerPhone);
    _address = TextEditingController(text: draft.address);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  SaleDraftController get _draft => ref.read(saleDraftProvider.notifier);

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _checkOrders = false;
    });
    try {
      final sale = ref.read(saleDraftProvider).toSale();
      final order = await ref.read(ordersRepositoryProvider).create(sale);
      if (!mounted) return;
      _finish(order);
    } on ConflictException catch (e) {
      await _handleConflict(e);
    } on ValidationException catch (e) {
      _draft.renewRequestKey();
      _fail(e.message);
    } on NetworkException catch (e) {
      // No se sabe si llegó: se reintenta con la misma clave.
      _fail('${e.message}\nPuedes reintentar: la venta no se registrará dos veces.');
    } on ApiException catch (e) {
      _fail(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Precios o stock cambiaron: se traen de nuevo para que la persona revise.
  Future<void> _handleConflict(ConflictException error) async {
    _draft.renewRequestKey();
    if (error.code == 'idempotency_conflict') {
      if (mounted) setState(() => _checkOrders = true);
      _fail('Es posible que la venta ya se haya registrado. Revísalo antes de intentar otra vez.');
      return;
    }
    final catalog = ref.read(catalogRepositoryProvider);
    for (final line in ref.read(saleDraftProvider).lines) {
      try {
        final fresh = await catalog.item(line.item.id);
        if (!mounted) return;
        _draft.refreshItem(fresh);
      } on ApiException {
        // Si no se puede actualizar, queda como estaba.
      }
    }
    refreshSalesData(ref);
    _fail(error.message);
  }

  void _fail(String message) {
    HapticFeedback.heavyImpact();
    if (mounted) setState(() => _error = message);
  }

  /// Deja la pestaña «Vender» lista para la siguiente y abre el pedido nuevo.
  void _finish(OrderDetail order) {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = _draft;
    refreshSalesData(ref);
    router.go(AppRoutes.sell);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.reset();
      router.go(AppRoutes.order(order.summary.id));
      messenger.showSnackBar(
        SnackBar(content: Text('Venta ${order.summary.number} registrada.')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(saleDraftProvider);
    final cart = draft.cart;
    final error = _error;

    return SafeArea(
      bottom: false,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        children: [
          BackLink('Productos', onTap: () => context.go(AppRoutes.sell)),
          Text('Cliente y pago', style: AppText.display(28, height: 1.1)),
          const SizedBox(height: 4),
          Text(
            'PASO 2 DE 2',
            style: AppText.mono(12, color: AppColors.muted, letterSpacing: 0.5),
          ),
          if (cart.lines.isEmpty) ...[
            const SizedBox(height: 14),
            if (error != null) ...[FormError(error), const SizedBox(height: 14)],
            CutButton(label: 'Elegir productos', onPressed: () => context.go(AppRoutes.sell)),
          ] else ...[
            const SizedBox(height: 12),
            LabeledField(
              label: 'Nombre del cliente',
              controller: _name,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [LengthLimitingTextInputFormatter(80)],
              onChanged: (v) => _draft.edit((d) => d.copyWith(customerName: v)),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'WhatsApp',
              controller: _phone,
              mono: true,
              enabled: !_busy,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                LengthLimitingTextInputFormatter(15),
              ],
              onChanged: (v) => _draft.edit((d) => d.copyWith(customerPhone: v)),
            ),
            const SizedBox(height: 12),
            Labeled(
              '¿Cómo llegó el cliente?',
              child: ChoiceBlocks<OrderOrigin>(
                options: [
                  for (final o in const [
                    OrderOrigin.inPerson,
                    OrderOrigin.whatsapp,
                    OrderOrigin.wholesale,
                  ])
                    (o, o.label),
                ],
                selected: draft.origin,
                onSelected: (o) => _draft.edit((d) => d.copyWith(origin: o)),
              ),
            ),
            const SizedBox(height: 12),
            Labeled(
              'Entrega',
              child: ChoiceBlocks<DeliveryType>(
                options: [for (final t in DeliveryType.values) (t, t.label)],
                selected: draft.deliveryType,
                onSelected: (t) => _draft.edit((d) => d.copyWith(deliveryType: t)),
              ),
            ),
            if (draft.deliveryType == DeliveryType.delivery) ...[
              const SizedBox(height: 12),
              LabeledField(
                label: 'Dirección de entrega',
                controller: _address,
                enabled: !_busy,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [LengthLimitingTextInputFormatter(200)],
                onChanged: (v) => _draft.edit((d) => d.copyWith(address: v)),
              ),
            ],
            const SizedBox(height: 12),
            Labeled(
              '¿Cómo pagó?',
              child: ChoiceBlocks<PaymentMethod>(
                options: [
                  for (final m in const [
                    PaymentMethod.qr,
                    PaymentMethod.transfer,
                    PaymentMethod.cash,
                  ])
                    (m, m.label),
                ],
                selected: draft.paymentMethod,
                onSelected: (m) => _draft.edit((d) => d.copyWith(paymentMethod: m)),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              draft.paymentMethod == PaymentMethod.cash
                  ? 'El efectivo se confirma cuando Jime valida la caja del día.'
                  : 'La venta queda «por pagar» hasta que subas el comprobante y Jime lo confirme.',
              style: AppText.body(12.5, FontWeight.w400, color: AppColors.muted, height: 1.3),
            ),
            const SizedBox(height: 10),
            const ColoredBox(color: AppColors.ink, child: SizedBox(height: 3)),
            const SizedBox(height: 4),
            LeaderRow(
              'Total a cobrar',
              cart.total.format(),
              labelStyle: AppText.body(17, FontWeight.w700),
              valueStyle: AppText.mono(17, weight: FontWeight.w700),
            ),
            const CommissionLine(label: 'Tu comisión'),
            if (error != null) ...[
              const SizedBox(height: 10),
              FormError(error),
              if (_checkOrders)
                TextLink('Ver mis pedidos', onTap: () => context.go(AppRoutes.orders)),
            ],
            const SizedBox(height: 12),
            CutButton(
              label: _busy
                  ? 'Registrando…'
                  : (draft.blockedReason ?? 'Registrar venta · ${cart.total.formatInline()}'),
              onPressed: draft.blockedReason == null ? _submit : null,
              busy: _busy,
            ),
          ],
        ],
      ),
    );
  }
}
