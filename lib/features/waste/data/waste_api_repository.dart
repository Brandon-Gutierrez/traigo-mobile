import '../../../core/network/api_client.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/json.dart';
import '../../../core/network/paged_result.dart';
import '../domain/waste.dart';

class WasteApiRepository implements WasteRepository {
  WasteApiRepository(this._api);

  final ApiClient _api;

  @override
  Future<WasteReport> create(CreateWasteInput input) async {
    final json = await _api.postMultipart(
      ApiPaths.waste,
      fields: {
        'item_id': input.itemId,
        'quantity': input.quantity,
        'reason': input.reason.apiValue,
        'note': input.note,
      },
      file: input.photo,
      fileField: 'photo',
      idempotencyKey: input.clientRequestId,
    );
    return WasteReport.fromJson(json.obj('data'));
  }

  @override
  Future<PagedResult<WasteReport>> list({WasteStatus? status, int page = 1}) async {
    final json = await _api.get(
      ApiPaths.waste,
      query: {if (status != null) 'status': status.apiValue, 'page': page},
    );
    return PagedResult.fromJson(json, WasteReport.fromJson);
  }
}
