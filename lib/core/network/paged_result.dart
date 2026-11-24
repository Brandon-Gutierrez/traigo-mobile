import 'json.dart';

/// Página de resultados con el formato de paginación de Laravel
/// (`data` + `meta.current_page / last_page / total`).
class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  /// Para listas completas que no vienen paginadas.
  PagedResult.single(List<T> items)
      : this(items: items, page: 1, lastPage: 1, total: items.length);

  factory PagedResult.fromJson(Json json, T Function(Json item) parse) {
    final meta = json.objOrNull('meta');
    final items = json.list('data').map(parse).toList();
    return PagedResult(
      items: items,
      page: meta?.integerOrNull('current_page') ?? 1,
      lastPage: meta?.integerOrNull('last_page') ?? 1,
      total: meta?.integerOrNull('total') ?? items.length,
    );
  }

  final List<T> items;
  final int page;
  final int lastPage;
  final int total;

  bool get hasMore => page < lastPage;
}
