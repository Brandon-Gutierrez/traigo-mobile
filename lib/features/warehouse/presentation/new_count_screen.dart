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
import '../../catalog/presentation/catalog_browser.dart';
import '../../orders/presentation/order_widgets.dart';
import '../../team/presentation/submit_errors.dart';
import '../application/count_draft.dart';
import '../application/warehouse_providers.dart';

/// Un conteo físico: se escribe lo que hay, sin ver lo que dice el sistema.
class NewCountScreen extends ConsumerStatefulWidget {
  const NewCountScreen({super.key});

  @override
  ConsumerState<NewCountScreen> createState() => _NewCountScreenState();
}

class _NewCountScreenState extends ConsumerState<NewCountScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final draft = ref.read(countDraftProvider);
    final controller = ref.read(countDraftProvider.notifier);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final count = await ref.read(warehouseRepositoryProvider).submitCount(
        clientUuid: draft.requestKey,
        countedOn: ref.read(todayProvider)(),
        counted: {for (final i in draft.items) i.productId: i.counted!},
      );
      if (!mounted) return;
      refreshWarehouseData(ref);
      controller.reset();
      router.go(AppRoutes.count(count.id));
      messenger.showSnackBar(const SnackBar(content: Text('Conteo guardado.')));
    } on ApiException catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _error = submitErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(countDraftProvider);
    final blocked = draft.blockedReason;
    final error = _error;
    final today = ref.watch(todayProvider)();

    return SafeArea(
      bottom: false,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        children: [
          BackLink('Conteos', onTap: () => context.go(AppRoutes.stockCounts)),
          Text('Nuevo conteo', style: AppText.display(28, height: 1.15)),
          const SizedBox(height: 4),
          Text(weekdayDate(today).toUpperCase(),
              style: AppText.mono(12, color: AppColors.muted)),
          const SizedBox(height: 8),
          Text(
            'Cuenta todo lo que hay en bodega, también lo reservado. Lo que dice el '
            'sistema aparece al guardar.',
            style: AppText.body(14, FontWeight.w400, color: AppColors.muted, height: 1.35),
          ),
          const SizedBox(height: 12),
          if (draft.items.isNotEmpty) const SectionHeader('Contado'),
          for (final item in draft.items)
            _CountField(
              item,
              key: ValueKey('count-field-${item.productId}'),
              enabled: !_busy,
            ),
          const SizedBox(height: 10),
          CutButton(
            label: '+ Agregar producto',
            height: 48,
            fontSize: 17,
            color: AppColors.ink,
            onPressed: _busy ? null : () => context.go(AppRoutes.newCountAdd),
          ),
          if (error != null) ...[const SizedBox(height: 10), FormError(error)],
          const SizedBox(height: 14),
          CutButton(
            label: _busy ? 'Guardando…' : (blocked ?? 'Guardar conteo'),
            onPressed: blocked == null ? _save : null,
            busy: _busy,
          ),
        ],
      ),
    );
  }
}

class _CountField extends ConsumerStatefulWidget {
  const _CountField(this.item, {super.key, required this.enabled});

  final CountDraftItem item;
  final bool enabled;

  @override
  ConsumerState<_CountField> createState() => _CountFieldState();
}

class _CountFieldState extends ConsumerState<_CountField> {
  late final _controller = TextEditingController(text: widget.item.counted?.toString() ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final draft = ref.read(countDraftProvider.notifier);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.rule, width: 2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.itemCode, style: AppText.mono(11, color: AppColors.muted)),
                Text(item.name, style: AppText.body(15, FontWeight.w600, height: 1.2)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Semantics(
              label: 'Unidades contadas de ${item.name}',
              child: TextField(
                controller: _controller,
                enabled: widget.enabled,
                textAlign: TextAlign.right,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(5),
                ],
                style: AppText.mono(18, weight: FontWeight.w700),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
                onChanged: (text) => draft.setCounted(item.productId, int.tryParse(text)),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Quitar ${item.name}',
            onPressed: widget.enabled ? () => draft.remove(item.productId) : null,
            icon: const Icon(Icons.close, size: 20, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// «Agregar producto» al conteo: sin cifras del sistema.
class CountProductPickerScreen extends ConsumerWidget {
  const CountProductPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(countDraftProvider);
    return CatalogBrowser(
      header: [
        BackLink('Conteo', onTap: () => context.go(AppRoutes.newCount)),
        Text('Agregar al conteo', style: AppText.display(28, height: 1.1)),
      ],
      detail: ProductRowDetail.none,
      noteFor: (item) => draft.contains(item.id) ? 'Ya está en el conteo' : null,
      onSelect: (item) {
        ref.read(countDraftProvider.notifier).add(item);
        context.go(AppRoutes.newCount);
      },
    );
  }
}
