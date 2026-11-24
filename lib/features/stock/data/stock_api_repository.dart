import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/json.dart';
import '../../../core/network/paged_result.dart';
import '../domain/stock.dart';

class StockApiRepository implements StockRepository {
  StockApiRepository(this._api);

  final ApiClient _api;

  @override
  Future<StockSummary> summary() async {
    final json = await _api.get(ApiPaths.stockSummary);
    return StockSummary.fromJson(json.obj('data'));
  }

  @override
  Future<PagedResult<StockMovement>> movements({DateTime? day, int page = 1}) async {
    final json = await _api.get(
      ApiPaths.stockMovements,
      query: {
        if (day != null) 'date': DateFormat('yyyy-MM-dd').format(day),
        'page': page,
      },
    );
    return PagedResult.fromJson(json, StockMovement.fromJson);
  }
}
