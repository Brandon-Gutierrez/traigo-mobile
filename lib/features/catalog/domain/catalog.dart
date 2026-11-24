import '../../../core/money/money.dart';
import '../../../core/network/json.dart';
import '../../../core/network/paged_result.dart';

enum CatalogKind {
  product('product', 'products'),
  combo('combo', 'combos');

  const CatalogKind(this.apiValue, this.pathSegment);

  /// Valor del campo `kind` en el JSON.
  final String apiValue;

  /// Segmento de URL: `/catalog/products/12`.
  final String pathSegment;

  static CatalogKind fromApi(String value) =>
      values.firstWhere((k) => k.apiValue == value);
}

enum StockLevel { ok, low, out }

/// Producto suelto o combo. Los dos se venden igual desde la app.
class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.kind,
    required this.code,
    required this.name,
    required this.category,
    required this.suggestedPrice,
    required this.minPrice,
    required this.stock,
    required this.lowStockAlert,
    this.imageUrl,
    this.components = const [],
  });

  factory CatalogItem.fromJson(Json json) => CatalogItem(
        id: json.str('id'),
        kind: CatalogKind.fromApi(json.str('kind')),
        code: json.str('code'),
        name: json.str('name'),
        category: json.strOrNull('category') ?? '',
        imageUrl: json.strOrNull('image_url'),
        suggestedPrice: json.money('suggested_price'),
        minPrice: json.money('min_price'),
        stock: json.integer('stock'),
        lowStockAlert: json.integer('low_stock_alert'),
        components: json.list('components').map(ComboComponent.fromJson).toList(),
      );

  final String id;
  final CatalogKind kind;
  final String code;
  final String name;
  final String category;
  final String? imageUrl;

  /// Precio normal de la tienda. Es el precio con el que parte la venta.
  final Money suggestedPrice;

  /// Piso para el vendedor, con el descuento de temporada ya aplicado.
  /// Vender por debajo está prohibido y el servidor lo rechaza.
  final Money minPrice;

  /// Unidades en bodega central. Para un combo, cuántos combos completos se
  /// pueden armar.
  final int stock;

  /// Desde cuántas unidades se avisa «poco stock».
  final int lowStockAlert;

  /// Solo combos: qué productos lo forman.
  final List<ComboComponent> components;

  bool get isCombo => kind == CatalogKind.combo;

  StockLevel get stockLevel {
    if (stock <= 0) return StockLevel.out;
    if (stock <= lowStockAlert) return StockLevel.low;
    return StockLevel.ok;
  }

  /// Ganancia máxima por unidad si se vende al precio sugerido.
  Money get maxGainPerUnit => suggestedPrice - minPrice;
}

class ComboComponent {
  const ComboComponent({required this.name, required this.quantity});

  factory ComboComponent.fromJson(Json json) => ComboComponent(
        name: json.str('name'),
        quantity: json.integer('quantity'),
      );

  final String name;
  final int quantity;
}

abstract interface class CatalogRepository {
  /// Productos y combos, con stock actual. [search] busca por nombre o código.
  Future<PagedResult<CatalogItem>> list({
    String? search,
    String? category,
    CatalogKind? kind,
    int page = 1,
  });

  Future<List<String>> categories();

  /// Un ítem con su stock y mínimo vigentes. Se usa justo antes de vender.
  Future<CatalogItem> get(CatalogKind kind, String id);
}
