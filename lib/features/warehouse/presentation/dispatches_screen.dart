import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../orders/domain/orders.dart';
import '../../orders/presentation/order_widgets.dart';
import '../application/warehouse_providers.dart';
import '../domain/warehouse.dart';

/// «5 por entregar · 1 atrasado».
String dispatchSummary(List<Dispatch> queue) {
  if (queue.isEmpty) return 'Nada por despachar';
  final late = queue.where((d) => d.isLate).length;
  final pending = '${queue.length} por entregar';
  if (late == 0) return pending;
  return '$pending · $late ${late == 1 ? 'atrasado' : 'atrasados'}';
}

/// Los pedidos pagados: primero se preparan y después se entregan.
class DispatchesScreen extends ConsumerWidget {
  const DispatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(dispatchQueueProvider);

    return RefreshablePage(
      onRefresh: () {
        ref.invalidate(dispatchQueueProvider);
        return ref.read(dispatchQueueProvider.future);
      },
      children: [
        BackLink('Inicio', onTap: () => context.go(AppRoutes.home)),
        Text('Despachos', style: AppText.display(30, height: 1.1)),
        const SizedBox(height: 4),
        ...queue.when(
          skipLoadingOnRefresh: true,
          data: _content,
          loading: () => const [
            SizedBox(height: 8),
            SkeletonBlock(height: 150),
            SizedBox(height: 12),
            SkeletonBlock(height: 150),
          ],
          error: (error, _) => [
            const SizedBox(height: 8),
            ErrorPanel(
              message: errorMessage(error),
              onRetry: () => ref.invalidate(dispatchQueueProvider),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _content(List<Dispatch> queue) {
    final toPrepare = queue.where((d) => d.status == OrderStatus.paid).toList();
    final ready = queue.where((d) => d.status == OrderStatus.ready).toList();
    return [
      Text(
        dispatchSummary(queue),
        style: AppText.body(14, FontWeight.w400, color: AppColors.muted),
      ),
      for (final (title, items) in [
        ('Por preparar', toPrepare),
        ('Listos para entregar', ready),
      ])
        if (items.isNotEmpty) ...[
          const SizedBox(height: 14),
          SectionHeader('$title (${items.length})'),
          for (final dispatch in items)
            _DispatchCard(dispatch, key: ValueKey('dispatch-${dispatch.orderId}')),
        ],
    ];
  }
}

class _DispatchCard extends ConsumerStatefulWidget {
  const _DispatchCard(this.dispatch, {super.key});

  final Dispatch dispatch;

  @override
  ConsumerState<_DispatchCard> createState() => _DispatchCardState();
}

class _DispatchCardState extends ConsumerState<_DispatchCard> {
  bool _busy = false;

  bool get _isReady => widget.dispatch.status == OrderStatus.ready;

  Future<bool> _confirmDelivery() async {
    final number = widget.dispatch.number;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Entregaste el $number?'),
        scrollable: true,
        content: const Text('Los productos salen del stock. No se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Todavía no')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí, entregado')),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _advance() async {
    final dispatch = widget.dispatch;
    final delivering = _isReady;
    if (delivering && !await _confirmDelivery()) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(warehouseRepositoryProvider);
    setState(() => _busy = true);
    try {
      delivering
          ? await repository.markDelivered(dispatch.orderId)
          : await repository.markReady(dispatch.orderId);
      messenger.showSnackBar(SnackBar(
        content: Text(
          delivering
              ? '${dispatch.number} entregado: salió del stock.'
              : '${dispatch.number} listo para entregar.',
        ),
      ));
    } on ApiException catch (e) {
      HapticFeedback.heavyImpact();
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
    if (!mounted) return;
    setState(() => _busy = false);
    refreshWarehouseData(ref);
  }

  @override
  Widget build(BuildContext context) {
    final dispatch = widget.dispatch;
    final today = ref.watch(todayProvider)();
    final promised = dispatch.promisedAt;
    final phone = dispatch.customerPhone;
    final address = dispatch.shippingAddress;
    final muted = AppText.body(13.5, FontWeight.w400, color: AppColors.muted, height: 1.3);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.rule, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                '${dispatch.number} · ${dispatch.deliveryType.label}'.toUpperCase(),
                style: AppText.mono(12, color: AppColors.muted),
              ),
              if (dispatch.isLate) const StatusMark(MarkKind.bad, 'Atrasado'),
            ],
          ),
          const SizedBox(height: 2),
          Text(dispatch.customerName, style: AppText.body(16, FontWeight.w600)),
          const SizedBox(height: 4),
          for (final line in dispatch.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 52,
                    child: Text('${line.quantity} ×',
                        style: AppText.mono(14, weight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: line.name,
                        children: [
                          TextSpan(
                            text: '  ${line.itemCode}',
                            style: AppText.mono(11.5, color: AppColors.muted),
                          ),
                        ],
                      ),
                      style: AppText.body(14.5, FontWeight.w400, height: 1.25),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          if (address != null) Text(address, style: muted),
          if (phone != null)
            Row(
              children: [
                Expanded(child: Text('WhatsApp $phone', style: muted)),
                IconButton(
                  tooltip: 'Copiar WhatsApp',
                  icon: const Icon(Icons.copy, size: 18, color: AppColors.violet),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: phone));
                    messenger.showSnackBar(const SnackBar(content: Text('Número copiado.')));
                  },
                ),
              ],
            ),
          Text(
            promised == null
                ? 'Sin hora acordada'
                : 'Acordado: ${longDate(promised, today)}',
            style: AppText.body(
              14,
              FontWeight.w600,
              color: dispatch.isLate ? AppColors.alert : AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          CutButton(
            label: _isReady ? 'Marcar entregado' : 'Marcar listo',
            height: 46,
            fontSize: 16,
            color: _isReady ? AppColors.violet : AppColors.ink,
            busy: _busy,
            onPressed: _advance,
          ),
        ],
      ),
    );
  }
}
