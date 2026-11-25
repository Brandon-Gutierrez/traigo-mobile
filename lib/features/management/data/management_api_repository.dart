import '../../../core/network/api_client.dart';
import '../../../core/network/api_paths.dart';
import '../domain/authorizations.dart';

class ManagementApiRepository implements ManagementRepository {
  ManagementApiRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<AuthorizationItem>> pending() async {
    final json = await _api.get(ApiPaths.authorizations);
    return json.list('data').map(AuthorizationItem.fromJson).toList();
  }

  @override
  Future<AuthorizationDetail> detail(AuthorizationType type, String id) async {
    final json = await _api.get(ApiPaths.authorization(type.apiValue, id));
    return AuthorizationDetail.fromJson(json.obj('data'));
  }

  @override
  Future<void> approve(AuthorizationType type, String id) =>
      _api.postNoContent(ApiPaths.authorizationApprove(type.apiValue, id));

  @override
  Future<void> sendBack(AuthorizationType type, String id, {required String reason}) =>
      _api.postNoContent(
        ApiPaths.authorizationReturn(type.apiValue, id),
        body: {'reason': reason},
      );
}
