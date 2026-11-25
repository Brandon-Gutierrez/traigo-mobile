import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/paged_result.dart';
import '../../../core/providers.dart';
import '../../auth/application/session_controller.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../home/application/home_providers.dart';
import '../domain/orders.dart';

typedef OrdersPageQuery = ({OrderFilter filter, int page});

final ordersPageProvider = FutureProvider.autoDispose
    .family<PagedResult<OrderSummary>, OrdersPageQuery>((ref, query) {
  ref.watch(sessionMemberIdProvider);
  return ref
      .watch(ordersRepositoryProvider)
      .list(filter: query.filter, page: query.page);
});

final orderDetailProvider =
    FutureProvider.autoDispose.family<OrderDetail, String>((ref, id) {
  ref.watch(sessionMemberIdProvider);
  return ref.watch(ordersRepositoryProvider).detail(id);
});

/// Una venta, un comprobante o una cancelación cambian el Inicio, los pedidos y
/// el stock del catálogo.
void refreshSalesData(WidgetRef ref) {
  ref
    ..invalidate(teamHomeProvider)
    ..invalidate(ordersPageProvider)
    ..invalidate(orderDetailProvider)
    ..invalidate(catalogPageProvider)
    ..invalidate(productProvider);
}
