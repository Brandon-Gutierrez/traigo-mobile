import '../../../core/network/api_client.dart';
import '../../../core/network/api_paths.dart';
import '../domain/home.dart';

class HomeApiRepository implements HomeRepository {
  HomeApiRepository(this._api);

  final ApiClient _api;

  @override
  Future<TeamHome> load() async {
    final json = await _api.get(ApiPaths.home);
    return TeamHome.fromJson(json.obj('data'));
  }
}
