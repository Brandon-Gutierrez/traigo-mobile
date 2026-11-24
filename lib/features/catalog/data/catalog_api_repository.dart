import '../../../core/network/api_client.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/json.dart';
import '../../../core/network/paged_result.dart';
import '../domain/catalog.dart';

class CatalogApiRepository implements CatalogRepository {
  CatalogApiRepository(this._api);

  final ApiClient _api;

  static const pageSize = 30;

  @override
  Future<PagedResult<CatalogItem>> list({
    String? search,
    String? category,
    CatalogKind? kind,
    int page = 1,
  }) async {
    final json = await _api.get(
      ApiPaths.catalog,
      query: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'category': ?category,
        'kind': ?kind?.apiValue,
        'page': page,
        'per_page': pageSize,
      },
    );
    return PagedResult.fromJson(json, CatalogItem.fromJson);
  }

  @override
  Future<List<String>> categories() async {
    final json = await _api.get(ApiPaths.categories);
    return (json['data'] as List? ?? const []).cast<String>();
  }

  @override
  Future<CatalogItem> get(CatalogKind kind, String id) async {
    final json = await _api.get(ApiPaths.catalogItem(kind.pathSegment, id));
    return CatalogItem.fromJson(json.obj('data'));
  }
}
