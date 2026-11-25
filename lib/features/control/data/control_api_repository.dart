import '../../../core/network/api_client.dart';
import '../../../core/network/api_paths.dart';
import '../domain/control_summary.dart';

class ControlApiRepository implements ControlRepository {
  ControlApiRepository(this._api);

  final ApiClient _api;

  @override
  Future<ControlSummary> summary() async {
    final json = await _api.get(ApiPaths.controlSummary);
    return ControlSummary.fromJson(json.obj('data'));
  }
}
