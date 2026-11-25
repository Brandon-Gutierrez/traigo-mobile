import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/session_controller.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../home/application/home_providers.dart';
import '../../orders/application/orders_providers.dart';
import '../domain/warehouse.dart';

/// La caja de hoy (`null`) o la de un día anterior.
final cashDayProvider =
    FutureProvider.autoDispose.family<CashDay, DateTime?>((ref, date) {
  ref.watch(sessionMemberIdProvider);
  final repository = ref.watch(warehouseRepositoryProvider);
  return date == null ? repository.cashToday() : repository.cashDay(date);
});

final dispatchQueueProvider = FutureProvider.autoDispose<List<Dispatch>>((ref) {
  ref.watch(sessionMemberIdProvider);
  return ref.watch(warehouseRepositoryProvider).dispatchQueue();
});

final inventoryCountsProvider =
    FutureProvider.autoDispose<List<InventoryCount>>((ref) {
  ref.watch(sessionMemberIdProvider);
  return ref.watch(warehouseRepositoryProvider).counts();
});

/// Una caja enviada, un despacho o un movimiento cambian el Inicio, los
/// pedidos y el stock del catálogo.
void refreshWarehouseData(WidgetRef ref) {
  ref
    ..invalidate(cashDayProvider)
    ..invalidate(dispatchQueueProvider)
    ..invalidate(inventoryCountsProvider)
    ..invalidate(teamHomeProvider)
    ..invalidate(ordersPageProvider)
    ..invalidate(orderDetailProvider)
    ..invalidate(catalogPageProvider)
    ..invalidate(productProvider);
}
