import '../../../core/network/api_client.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/json.dart';
import '../../../core/network/paged_result.dart';
import '../domain/orders.dart';

class OrdersApiRepository implements OrdersRepository {
  OrdersApiRepository(this._api);

  final ApiClient _api;

  @override
  Future<PagedResult<OrderSummary>> list({OrderStatus? status, int page = 1}) async {
    final json = await _api.get(
      ApiPaths.orders,
      query: {if (status != null) 'status': status.apiValue, 'page': page},
    );
    return PagedResult.fromJson(json, OrderSummary.fromJson);
  }

  @override
  Future<OrderDetail> get(String id) async {
    final json = await _api.get(ApiPaths.order(id));
    return OrderDetail.fromJson(json.obj('data'));
  }

  @override
  Future<OrderDetail> create(CreateOrderInput input) async {
    final json = await _api.post(
      ApiPaths.orders,
      body: input.toJson(),
      idempotencyKey: input.clientRequestId,
    );
    return OrderDetail.fromJson(json.obj('data'));
  }

  @override
  Future<OrderDetail> cancel(String id) async {
    final json = await _api.post(ApiPaths.orderCancel(id));
    return OrderDetail.fromJson(json.obj('data'));
  }

  @override
  Future<OrderDetail> uploadPaymentProof(
    String id,
    UploadFile file, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final json = await _api.postMultipart(
      ApiPaths.orderPaymentProof(id),
      fields: const {},
      file: file,
      fileField: 'proof',
      onProgress: onProgress,
    );
    return OrderDetail.fromJson(json.obj('data'));
  }
}
