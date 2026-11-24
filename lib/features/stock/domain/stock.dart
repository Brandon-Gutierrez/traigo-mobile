import '../../../core/network/json.dart';
import '../../../core/network/paged_result.dart';
import '../../catalog/domain/catalog.dart';

enum StockMovementType {
  sale('sale'),
  entry('entry'),
  waste('waste'),
  adjustment('adjustment'),
  returned('returned'),
  cancelled('cancelled');

  const StockMovementType(this.apiValue);
  final String apiValue;

  static StockMovementType fromApi(String v) =>
      values.firstWhere((e) => e.apiValue == v, orElse: () => adjustment);
}

class StockMovement {
  const StockMovement({
    required this.id,
    required this.occurredAt,
    required this.quantityDelta,
    required this.itemName,
    required this.description,
    required this.type,
    required this.pending,
  });

  factory StockMovement.fromJson(Json json) => StockMovement(
        id: json.str('id'),
        occurredAt: json.date('occurred_at'),
        quantityDelta: json.integer('quantity_delta'),
        itemName: json.str('item_name'),
        description: json.str('description'),
        type: StockMovementType.fromApi(json.str('type')),
        pending: json.flag('pending'),
      );

  final String id;
  final DateTime occurredAt;

  /// Negativo si salió stock, positivo si entró.
  final int quantityDelta;
  final String itemName;
  final String description;
  final StockMovementType type;

  /// Merma esperando aprobación: todavía no cambió el stock real.
  final bool pending;
}

class StockSummary {
  const StockSummary({
    required this.productsTotal,
    required this.lowCount,
    required this.outCount,
    required this.attention,
  });

  factory StockSummary.fromJson(Json json) => StockSummary(
        productsTotal: json.integer('products_total'),
        lowCount: json.integer('low_count'),
        outCount: json.integer('out_count'),
        attention: json.list('attention_items').map(CatalogItem.fromJson).toList(),
      );

  final int productsTotal;
  final int lowCount;
  final int outCount;

  /// Productos con poco stock o agotados, para «Poco stock».
  final List<CatalogItem> attention;
}

abstract interface class StockRepository {
  Future<StockSummary> summary();

  /// Movimientos del día indicado (por defecto hoy).
  Future<PagedResult<StockMovement>> movements({DateTime? day, int page = 1});
}
