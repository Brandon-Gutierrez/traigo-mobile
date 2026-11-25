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
import '../../orders/presentation/order_widgets.dart';
import '../../team/presentation/submit_errors.dart';
import '../application/warehouse_providers.dart';
import '../domain/warehouse.dart';

/// El resultado de un conteo: lo contado contra el sistema y el ajuste de
/// cada diferencia.
class CountScreen extends ConsumerWidget {
  const CountScreen({
    super.key,
    required this.countId,
    this.readOnly = false,
    this.backRoute = AppRoutes.stockCounts,
  });

  final String countId;

  /// Jime lo ve, pero ajustar es de almacén.
  final bool readOnly;
  final String backRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(inventoryCountsProvider);

    return RefreshablePage(
      onRefresh: () {
        ref.invalidate(inventoryCountsProvider);
        return ref.read(inventoryCountsProvider.future);
      },
      children: [
        BackLink('Conteos', onTap: () => context.go(backRoute)),
        Text('Conteo', style: AppText.display(28, height: 1.15)),
        const SizedBox(height: 4),
        ...counts.when(
          skipLoadingOnRefresh: true,
          data: (data) {
            final count = data.where((c) => c.id == countId).firstOrNull;
            if (count == null) {
              return [
                Text(
                  'No encontramos ese conteo.',
                  style: AppText.body(15, FontWeight.w400, color: AppColors.muted),
                ),
              ];
            }
            return [
              Text(
                weekdayDate(count.countedOn).toUpperCase(),
                style: AppText.mono(12, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              for (final item in count.items)
                _CountedRow(
                  count,
                  item,
                  readOnly: readOnly,
                  key: ValueKey('counted-${item.productId}'),
                ),
              const SizedBox(height: 8),
              Text(
                readOnly
                    ? 'El conteo queda tal cual para el KPI «Exactitud del inventario». '
                        'Los ajustes los hace almacén con su motivo.'
                    : 'El conteo se guarda tal cual para tu KPI «Exactitud del inventario». '
                        'Un ajuste corrige el stock y queda en el historial con tu motivo.',
                style: AppText.body(12.5, FontWeight.w400, color: AppColors.muted, height: 1.35),
              ),
            ];
          },
          loading: () => const [SizedBox(height: 8), SkeletonBlock(height: 140)],
          error: (error, _) => [
            ErrorPanel(
              message: errorMessage(error),
              onRetry: () => ref.invalidate(inventoryCountsProvider),
            ),
          ],
        ),
      ],
    );
  }
}

/// `+3`, `−2`.
String signedCount(int value) => value > 0 ? '+$value' : '−${value.abs()}';

class _CountedRow extends ConsumerWidget {
  const _CountedRow(this.count, this.item, {required this.readOnly, super.key});

  final InventoryCount count;
  final CountedProduct item;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final difference = item.difference;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.rule, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(item.itemCode, style: AppText.mono(11, color: AppColors.muted)),
          Text(item.name, style: AppText.body(15, FontWeight.w600, height: 1.2)),
          const SizedBox(height: 2),
          LeaderRow('Sistema', '${item.systemQty} u.'),
          LeaderRow('Contado', '${item.countedQty} u.'),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: StatusMark(
              difference == 0 || item.adjusted ? MarkKind.ok : MarkKind.bad,
              difference == 0
                  ? 'Cuadra'
                  : 'Diferencia ${signedCount(difference)}${item.adjusted ? ' · ajustada' : ''}',
            ),
          ),
          if (item.needsAdjustment && !readOnly) ...[
            const SizedBox(height: 8),
            CutButton(
              label: 'Ajustar ${signedCount(difference)}',
              height: 46,
              fontSize: 16,
              color: AppColors.ink,
              onPressed: () => _adjust(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _adjust(BuildContext context, WidgetRef ref) async {
    final done = await showDialog<StockLevel>(
      context: context,
      builder: (_) => _AdjustDialog(count.id, item),
    );
    if (done == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Stock corregido: ${done.stock} en bodega.')),
    );
    refreshWarehouseData(ref);
  }
}

/// El ajuste ya viene calculado: solo se escribe el motivo.
class _AdjustDialog extends ConsumerStatefulWidget {
  const _AdjustDialog(this.countId, this.item);

  final String countId;
  final CountedProduct item;

  @override
  ConsumerState<_AdjustDialog> createState() => _AdjustDialogState();
}

class _AdjustDialogState extends ConsumerState<_AdjustDialog> {
  String _requestKey = const Uuid().v4();
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final level = await ref.read(warehouseRepositoryProvider).registerStock(
            clientUuid: _requestKey,
            productId: widget.item.productId,
            type: widget.item.adjustmentType,
            quantity: widget.item.difference.abs(),
            note: _reason.text.trim(),
            inventoryCountId: widget.countId,
          );
      if (mounted) Navigator.pop(context, level);
    } on ApiException catch (e) {
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      setState(() => _error = submitErrorMessage(e));
      // Por ejemplo, ya se había ajustado desde otro celular.
      if (e is ConflictException) ref.invalidate(inventoryCountsProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final reason = _reason.text.trim();
    return AlertDialog(
      title: Text('Ajustar ${signedCount(widget.item.difference)}'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${widget.item.name}. Queda en el historial y no se puede borrar.'),
          const SizedBox(height: 12),
          LabeledField(
            label: 'Motivo del ajuste',
            controller: _reason,
            lines: 2,
            enabled: !_busy,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(300)],
            onChanged: (_) => setState(() {
              _requestKey = const Uuid().v4();
              _error = null;
            }),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error, style: AppText.body(13.5, FontWeight.w600, color: AppColors.alert)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Volver'),
        ),
        TextButton(
          onPressed: _busy || reason.isEmpty ? null : _send,
          child: Text(_busy ? 'Ajustando…' : 'Ajustar'),
        ),
      ],
    );
  }
}
