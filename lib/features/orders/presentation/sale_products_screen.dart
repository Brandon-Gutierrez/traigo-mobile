import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/cut_button.dart';
import '../../../core/ui/ficha.dart';
import '../../catalog/domain/pricing.dart';
import '../../catalog/presentation/product_art.dart';
import '../application/sale_draft.dart';
import 'commission_line.dart';

/// Registrar venta, paso 1: productos y cantidades. El precio por mayor se
/// aplica solo al llegar al mínimo de cada producto.
class SaleProductsScreen extends ConsumerWidget {
  const SaleProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(saleDraftProvider);
    final cart = draft.cart;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        children: [
          Text('Registrar venta', style: AppText.display(30, height: 1.1)),
          const SizedBox(height: 4),
          Text(
            'PASO 1 DE 2 · PRODUCTOS',
            style: AppText.mono(12, color: AppColors.muted, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          if (cart.lines.isEmpty) ...[
            Text(
              'Agrega lo que vas a vender desde el catálogo.',
              style: AppText.body(15, FontWeight.w400, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            CutButton(
              label: 'Elegir productos',
              onPressed: () => context.go(AppRoutes.sellAdd),
            ),
          ] else ...[
            for (final line in cart.lines) _SaleLine(line),
            _AddAnother(onTap: () => context.go(AppRoutes.sellAdd)),
            const SizedBox(height: 10),
            _Totals(cart),
            const CommissionLine(label: 'Tu comisión'),
            const SizedBox(height: 10),
            CutButton(
              label: 'Continuar · ${cart.total.formatInline()}',
              onPressed: () => context.go(AppRoutes.sellCustomer),
            ),
          ],
        ],
      ),
    );
  }
}

class _SaleLine extends ConsumerWidget {
  const _SaleLine(this.line);

  final CartLine line;

  String get _hint {
    final item = line.item;
    if (line.quantity >= item.available) return 'Solo hay ${item.available} disponibles';
    if (line.reachesMinimum) return 'Llegó al mínimo de ${item.wholesaleMinQty} u.';
    final missing = line.missingForMinimum;
    if (missing == null) return 'Sin precio por mayor';
    return '${missing == 1 ? 'Falta 1 u.' : 'Faltan $missing u.'} '
        'para ${item.priceWholesale!.formatInline()} c/u';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = line.item;
    final controller = ref.read(saleDraftProvider.notifier);
    final wholesale = line.reachesMinimum;

    return Container(
      key: ValueKey('sale-line-${item.itemCode}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.ink, width: 3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ProductTile(category: item.category, imageUrl: item.imageUrl, size: 44),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.itemCode, style: AppText.mono(11, color: AppColors.muted)),
                    Text(item.name, style: AppText.body(15.5, FontWeight.w600, height: 1.15)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(line.total.format(), style: AppText.display(18)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SquareIconButton(
                icon: line.quantity == 1 ? Icons.delete_outline : Icons.remove,
                tooltip: line.quantity == 1
                    ? 'Quitar ${item.name}'
                    : 'Una unidad menos de ${item.name}',
                onPressed: () => controller.setQuantity(item.id, line.quantity - 1),
              ),
              Semantics(
                button: true,
                label: 'Cantidad ${line.quantity}. Toca para escribirla',
                excludeSemantics: true,
                child: InkWell(
                  onTap: () async {
                    final quantity = await showDialog<int>(
                      context: context,
                      builder: (_) => _QuantityDialog(line),
                    );
                    if (quantity != null) controller.setQuantity(item.id, quantity);
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 60, minHeight: 48),
                    child: Center(
                      widthFactor: 1,
                      child: Text('${line.quantity}', style: AppText.display(26, height: 1)),
                    ),
                  ),
                ),
              ),
              _PlusButton(
                name: item.name,
                onPressed: line.quantity < item.available
                    ? () => controller.setQuantity(item.id, line.quantity + 1)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${wholesale ? 'Mayorista' : 'Minorista'} '
                      '${line.unitPrice.formatInline()} c/u',
                      textAlign: TextAlign.end,
                      style: AppText.body(
                        13.5,
                        FontWeight.w700,
                        color: wholesale ? AppColors.violet : AppColors.ink,
                      ),
                    ),
                    Text(
                      _hint,
                      textAlign: TextAlign.end,
                      style: AppText.body(12, FontWeight.w400, color: AppColors.muted, height: 1.25),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlusButton extends StatelessWidget {
  const _PlusButton({required this.name, required this.onPressed});

  final String name;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.35 : 1,
      child: SquareIconButton(
        icon: Icons.add,
        tooltip: 'Una unidad más de $name',
        onPressed: onPressed ?? () {},
      ),
    );
  }
}

/// Escribir la cantidad: para pedidos grandes, mejor que tocar «+» 24 veces.
class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog(this.line);

  final CartLine line;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late final _controller = TextEditingController(text: '${widget.line.quantity}')
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: '${widget.line.quantity}'.length,
    );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _accept() {
    final value = int.tryParse(_controller.text);
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.line.item;
    return AlertDialog(
      title: const Text('Cantidad'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onSubmitted: (_) => _accept(),
        style: AppText.mono(22, weight: FontWeight.w700),
        decoration: InputDecoration(
          helperText: 'Disponibles: ${item.available}'
              '${item.wholesaleMinQty == null ? '' : ' · por mayor desde ${item.wholesaleMinQty}'}',
          helperMaxLines: 2,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(onPressed: _accept, child: const Text('Aceptar')),
      ],
    );
  }
}

class _AddAnother extends StatelessWidget {
  const _AddAnother({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: CustomPaint(
          painter: const _DashedBorder(),
          child: SizedBox(
            height: 48,
            child: Center(
              child: Text('+ Agregar otro producto', style: AppText.body(15, FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final border = Path()..addRect(Rect.fromLTWH(1, 1, size.width - 2, size.height - 2));
    for (final metric in border.computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += 10) {
        canvas.drawPath(metric.extractPath(at, at + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder oldDelegate) => false;
}

class _Totals extends StatelessWidget {
  const _Totals(this.cart);

  final PricedCart cart;

  @override
  Widget build(BuildContext context) {
    final mixed = !cart.wholesaleTotal.isZero && !cart.unitTotal.isZero;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ColoredBox(color: AppColors.ink, child: SizedBox(height: 3)),
        const SizedBox(height: 4),
        if (mixed) ...[
          LeaderRow('Mayorista', cart.wholesaleTotal.format()),
          LeaderRow('Minorista', cart.unitTotal.format()),
        ],
        LeaderRow(
          'Total',
          cart.total.format(),
          labelStyle: AppText.body(17, FontWeight.w700),
          valueStyle: AppText.mono(17, weight: FontWeight.w700),
        ),
      ],
    );
  }
}
