/// Catálogo único por código (SKU).
library;

import '../../../core/money/money.dart';
import '../../../core/network/json.dart';
import '../../../core/network/paged_result.dart';

class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.itemCode,
    required this.name,
    required this.category,
    required this.priceUnit,
    required this.stock,
    required this.reserved,
    required this.available,
    this.priceWholesale,
    this.wholesaleMinQty,
    this.commissionPct,
    this.imageUrl,
    this.description,
    this.imageUrls = const [],
  });

  factory CatalogItem.fromJson(Json json) => CatalogItem(
        id: json.str('id'),
        itemCode: json.str('item_code'),
        name: json.str('name'),
        category: json.str('category'),
        priceUnit: json.money('price_unit'),
        priceWholesale: json.moneyOrNull('price_wholesale'),
        wholesaleMinQty: json.integerOrNull('wholesale_min_qty'),
        stock: json.integer('stock'),
        reserved: json.integer('reserved'),
        available: json.integer('available'),
        commissionPct: json['commission_pct'] == null ? null : json.rate('commission_pct'),
        imageUrl: json.strOrNull('image_url'),
        description: json.strOrNull('description'),
        imageUrls: json.strings('images'),
      );

  final String id;
  final String itemCode;
  final String name;
  final String category;
  final Money priceUnit;
  final Money? priceWholesale;

  /// Unidades mínimas del mismo código para el precio por mayor.
  final int? wholesaleMinQty;

  /// En bodega.
  final int stock;

  /// Apartado por pedidos.
  final int reserved;

  /// Lo que se puede vender.
  final int available;

  /// % de comisión del producto. `null` = por definir (la app muestra
  /// «[% por definir]»).
  final double? commissionPct;
  final String? imageUrl;

  /// Solo en el detalle.
  final String? description;
  final List<String> imageUrls;

  bool get soldOut => available <= 0;
}

class CatalogCategory {
  const CatalogCategory({required this.id, required this.name, required this.count});

  factory CatalogCategory.fromJson(Json json) => CatalogCategory(
        id: json.str('id'),
        name: json.str('name'),
        count: json.integer('count'),
      );

  final String id;
  final String name;
  final int count;
}

abstract interface class CatalogRepository {
  /// Productos activos por nombre; [search] busca en nombre y código.
  Future<PagedResult<CatalogItem>> list({String? search, String? categoryId, int page = 1});

  Future<List<CatalogCategory>> categories();

  Future<CatalogItem> item(String id);
}
