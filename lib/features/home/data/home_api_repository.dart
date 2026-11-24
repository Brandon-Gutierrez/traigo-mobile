import '../../../core/network/api_client.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/json.dart';
import '../domain/home.dart';

class HomeApiRepository implements HomeRepository {
  HomeApiRepository(this._api);

  final ApiClient _api;

  @override
  Future<HomeSummary> load() async {
    final json = await _api.get(ApiPaths.home);
    return HomeSummary.fromJson(json.obj('data'));
  }
}
