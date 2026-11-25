import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/app_routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/cut_button.dart';
import '../../../core/ui/error_panel.dart';
import '../../../core/ui/ficha.dart';
import '../../../core/ui/form_pieces.dart';
import '../../../core/ui/refreshable_page.dart';
import '../../../core/ui/skeleton_block.dart';
import '../../auth/presentation/auth_frame.dart' show FormError;
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/domain/catalog.dart';
import '../../catalog/presentation/product_art.dart';
import '../../team/presentation/submit_errors.dart';
import '../application/warehouse_providers.dart';
import '../domain/warehouse.dart';

/// El stock de un producto y el registro de ingresos y ajustes.
class StockProductScreen extends ConsumerWidget {
  const StockProductScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productProvider(productId));

    return RefreshablePage(
      onRefresh: () {
        ref.invalidate(productProvider(productId));
        return ref.read(productProvider(productId).future);
      },
      children: [
        BackLink('Stock', onTap: () => context.go(AppRoutes.stock)),
        ...product.when(
          skipLoadingOnRefresh: true,
          data: (item) => [_StockBody(item)],
          loading: () => const [
            SkeletonBlock(height: 100),
            SizedBox(height: 14),
            SkeletonBlock(height: 200),
          ],
          error: (error, _) => [
            ErrorPanel(
              message: errorMessage(error),
              onRetry: () => ref.invalidate(productProvider(productId)),
            ),
          ],
        ),
      ],
    );
  }
}

class _StockBody extends StatelessWidget {
  const _StockBody(this.item);

  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ProductTile(category: item.category, imageUrl: item.imageUrl, size: 64),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.itemCode, style: AppText.mono(12, color: AppColors.muted)),
                  Text(item.name, style: AppText.display(22, height: 1.15)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const SectionHeader('Inventario'),
        LeaderRow('En bodega', '${item.stock} u.'),
        LeaderRow('Reservado por pedidos', '${item.reserved} u.'),
        LeaderRow(
          'Disponible',
          '${item.available} u.',
          labelStyle: AppText.body(16, FontWeight.w700),
        ),
        const SizedBox(height: 14),
        const SectionHeader('Registrar movimiento'),
        const SizedBox(height: 4),
        _MovementForm(item, key: ValueKey(item.id)),
      ],
    );
  }
}

class _MovementForm extends ConsumerStatefulWidget {
  const _MovementForm(this.item, {super.key});

  final CatalogItem item;

  @override
  ConsumerState<_MovementForm> createState() => _MovementFormState();
}

class _MovementFormState extends ConsumerState<_MovementForm> {
  String _requestKey = const Uuid().v4();
  StockEntryType _type = StockEntryType.purchase;
  final _quantity = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  void _edit([VoidCallback? change]) => setState(() {
        change?.call();
        _requestKey = const Uuid().v4();
        _error = null;
      });

  static String _choiceLabel(StockEntryType type) => switch (type) {
        StockEntryType.initial => 'Inicial',
        StockEntryType.purchase => 'Ingreso',
        StockEntryType.adjustmentIn => 'Sobra',
        StockEntryType.adjustmentOut => 'Falta',
      };

  bool get _isAdjustment =>
      _type == StockEntryType.adjustmentIn || _type == StockEntryType.adjustmentOut;

  int get _amount => int.tryParse(_quantity.text) ?? 0;

  String? get _blockedReason {
    if (_amount < 1) return 'Escribe la cantidad';
    if (_type == StockEntryType.adjustmentOut && _amount > widget.item.available) {
      return 'Solo puedes quitar ${widget.item.available}';
    }
    if (_isAdjustment && _note.text.trim().isEmpty) return 'Escribe el motivo';
    return null;
  }

  Future<bool> _confirm() async {
    final signed = _type.signed(_amount);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Registrar ${_type.label.toLowerCase()}?'),
        scrollable: true,
        content: Text(
          '${signed > 0 ? '+' : '−'}$_amount de ${widget.item.name}. En bodega quedarán '
          '${widget.item.stock + signed}.\n\nQueda en el historial y no se puede borrar.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Volver')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Registrar')),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!await _confirm() || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final note = _note.text.trim();
      final level = await ref.read(warehouseRepositoryProvider).registerStock(
            clientUuid: _requestKey,
            productId: widget.item.id,
            type: _type,
            quantity: _amount,
            note: note.isEmpty ? null : note,
          );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Stock actualizado: ${level.stock} en bodega.')),
      );
      _quantity.clear();
      _note.clear();
      // «Inicial» desaparece cuando ya hay stock.
      _edit(() => _type = StockEntryType.purchase);
      refreshWarehouseData(ref);
    } on ApiException catch (e) {
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      setState(() => _error = submitErrorMessage(e));
      if (e is ConflictException) refreshWarehouseData(ref);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _blockedReason;
    final error = _error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChoiceBlocks<StockEntryType>(
          options: [
            // La carga inicial es solo para un producto sin stock.
            for (final type in StockEntryType.values)
              if (type != StockEntryType.initial || widget.item.stock == 0)
                (type, _choiceLabel(type)),
          ],
          selected: _type,
          onSelected: (type) {
            if (!_busy && type != _type) _edit(() => _type = type);
          },
        ),
        const SizedBox(height: 4),
        Text(
          switch (_type) {
            StockEntryType.initial => 'Primera carga de un producto sin stock.',
            StockEntryType.purchase => 'Mercadería que llegó.',
            StockEntryType.adjustmentIn => 'Hay más de lo que dice el sistema.',
            StockEntryType.adjustmentOut => 'Hay menos de lo que dice el sistema.',
          },
          style: AppText.body(12.5, FontWeight.w400, color: AppColors.muted),
        ),
        const SizedBox(height: 10),
        LabeledField(
          label: 'Cantidad',
          controller: _quantity,
          mono: true,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(5),
          ],
          onChanged: (_) => _edit(),
        ),
        const SizedBox(height: 10),
        LabeledField(
          label: _isAdjustment ? 'Motivo del ajuste' : 'Nota (opcional)',
          controller: _note,
          lines: 2,
          enabled: !_busy,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [LengthLimitingTextInputFormatter(300)],
          onChanged: (_) => _edit(),
        ),
        if (error != null) ...[const SizedBox(height: 10), FormError(error)],
        const SizedBox(height: 12),
        CutButton(
          label: _busy ? 'Registrando…' : (blocked ?? 'Registrar'),
          onPressed: blocked == null ? _send : null,
          busy: _busy,
        ),
      ],
    );
  }
}
