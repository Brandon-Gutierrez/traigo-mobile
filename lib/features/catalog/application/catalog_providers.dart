import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/paged_result.dart';
import '../../../core/providers.dart';
import '../../auth/application/session_controller.dart';
import '../domain/catalog.dart';

typedef CatalogPageQuery = ({String search, String? categoryId, int page});

final catalogCategoriesProvider = FutureProvider.autoDispose<List<CatalogCategory>>((ref) {
  ref.watch(sessionMemberIdProvider);
  return ref.watch(catalogRepositoryProvider).categories();
});

/// Una página de resultados. La pantalla junta las páginas que pidió.
final catalogPageProvider = FutureProvider.autoDispose
    .family<PagedResult<CatalogItem>, CatalogPageQuery>((ref, query) {
  ref.watch(sessionMemberIdProvider);
  return ref.watch(catalogRepositoryProvider).list(
        search: query.search,
        categoryId: query.categoryId,
        page: query.page,
      );
});

final productProvider = FutureProvider.autoDispose.family<CatalogItem, String>((ref, id) {
  ref.watch(sessionMemberIdProvider);
  return ref.watch(catalogRepositoryProvider).item(id);
});
