import '../../../core/network/api_client.dart';
import '../../../core/network/api_paths.dart';
import '../../team/data/team_api_repository.dart' show apiDate;
import '../domain/warehouse.dart';

class WarehouseApiRepository implements WarehouseRepository {
  WarehouseApiRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Dispatch>> dispatchQueue() async {
    final json = await _api.get(ApiPaths.dispatches);
    return json.list('data').map(Dispatch.fromJson).toList();
  }

  @override
  Future<void> markReady(String orderId) =>
      _api.postNoContent(ApiPaths.dispatchReady(orderId));

  @override
  Future<void> markDelivered(String orderId) =>
      _api.postNoContent(ApiPaths.dispatchDelivered(orderId));

  @override
  Future<StockLevel> registerStock({
    required String clientUuid,
    required String productId,
    required StockEntryType type,
    required int quantity,
    String? note,
  }) async {
    final json = await _api.post(
      ApiPaths.stockMovements,
      idempotencyKey: clientUuid,
      body: {
        'product_id': productId,
        'type': type.apiValue,
        'quantity': type.signed(quantity),
        'note': note,
      },
    );
    return StockLevel.fromJson(json.obj('data'));
  }

  @override
  Future<CashDay> cashToday() async {
    final json = await _api.get(ApiPaths.cashToday);
    return CashDay.fromJson(json.obj('data'));
  }

  @override
  Future<CashDay> sendClosing(NewCashClosing closing) async {
    final json = await _api.post(
      ApiPaths.cashClosings,
      idempotencyKey: closing.clientUuid,
      body: {
        'business_date': apiDate(closing.businessDate),
        'lines': [
          for (final MapEntry(key: method, value: amount) in closing.counted.entries)
            {'method': method.apiValue, 'counted': amount.toApi()},
        ],
        'note': closing.note,
      },
    );
    return CashDay.fromJson(json.obj('data'));
  }

  @override
  Future<List<InventoryCount>> counts() async {
    final json = await _api.get(ApiPaths.inventoryCounts);
    return json.list('data').map(InventoryCount.fromJson).toList();
  }

  @override
  Future<InventoryCount> submitCount({
    required String clientUuid,
    required DateTime countedOn,
    required Map<String, int> counted,
    String? note,
  }) async {
    final json = await _api.post(
      ApiPaths.inventoryCounts,
      idempotencyKey: clientUuid,
      body: {
        'counted_on': apiDate(countedOn),
        'items': [
          for (final MapEntry(key: productId, value: quantity) in counted.entries)
            {'product_id': productId, 'counted_qty': quantity},
        ],
        'note': note,
      },
    );
    return InventoryCount.fromJson(json.obj('data'));
  }
}
