import '../../../core/network/api_client.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/paged_result.dart';
import '../domain/catalog.dart';

class CatalogApiRepository implements CatalogRepository {
  CatalogApiRepository(this._api);

  final ApiClient _api;

  @override
  Future<PagedResult<CatalogItem>> list({
    String? search,
    String? categoryId,
    int page = 1,
  }) async {
    final text = search?.trim();
    final json = await _api.get(
      ApiPaths.catalog,
      query: {
        if (text != null && text.isNotEmpty) 'search': text,
        'category': ?categoryId,
        'page': page,
      },
    );
    return PagedResult.fromJson(json, CatalogItem.fromJson);
  }

  @override
  Future<List<CatalogCategory>> categories() async {
    final json = await _api.get(ApiPaths.catalogCategories);
    return json.list('data').map(CatalogCategory.fromJson).toList();
  }

  @override
  Future<CatalogItem> item(String id) async {
    final json = await _api.get(ApiPaths.catalogItem(id));
    return CatalogItem.fromJson(json.obj('data'));
  }
}
