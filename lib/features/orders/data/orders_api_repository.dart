import '../../../core/network/api_client.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/paged_result.dart';
import '../domain/orders.dart';

class OrdersApiRepository implements OrdersRepository {
  OrdersApiRepository(this._api);

  final ApiClient _api;

  @override
  Future<PagedResult<OrderSummary>> list({
    OrderFilter filter = OrderFilter.all,
    int page = 1,
  }) async {
    final json = await _api.get(
      ApiPaths.orders,
      query: {'status': ?filter.apiValue, 'page': page},
    );
    return PagedResult.fromJson(json, OrderSummary.fromJson);
  }

  @override
  Future<OrderDetail> detail(String id) async => _read(await _api.get(ApiPaths.order(id)));

  @override
  Future<OrderDetail> create(NewSale sale) async => _read(
        await _api.post(ApiPaths.orders, body: sale.toJson(), idempotencyKey: sale.clientUuid),
      );

  @override
  Future<OrderDetail> cancel(String id, {String? reason}) async =>
      _read(await _api.post(ApiPaths.orderCancel(id), body: {'reason': reason}));

  @override
  Future<OrderDetail> uploadProof(
    String id, {
    required UploadFile file,
    required String clientUuid,
    String? reference,
  }) async =>
      _read(await _api.postMultipart(
        ApiPaths.orderPaymentProof(id),
        fields: {'reference': reference},
        file: file,
        idempotencyKey: clientUuid,
      ));

  OrderDetail _read(Json json) => OrderDetail.fromJson(json.obj('data'));
}
