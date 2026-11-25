import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/cut_button.dart';
import '../../../core/ui/error_panel.dart';
import '../../../core/ui/form_pieces.dart';
import '../../../core/ui/refreshable_page.dart';
import '../../../core/ui/skeleton_block.dart';
import '../application/catalog_providers.dart';
import '../domain/catalog.dart';
import 'product_art.dart';

/// Qué se muestra de cada producto bajo su nombre.
enum ProductRowDetail {
  /// Precios y disponible (catálogo y venta).
  prices,

  /// Bodega, reservado y disponible (almacén).
  stock,

  /// Nada: en el conteo no se mira lo que dice el sistema.
  none,
}

/// Buscador, categorías y lista de productos. Lo usan el Catálogo, «Agregar
/// producto» de la venta y almacén.
class CatalogBrowser extends ConsumerStatefulWidget {
  const CatalogBrowser({
    super.key,
    required this.header,
    required this.onSelect,
    this.noteFor,
    this.detail = ProductRowDetail.prices,
  });

  final ProductRowDetail detail;

  /// Lo que va arriba del buscador (título).
  final List<Widget> header;
  final ValueChanged<CatalogItem> onSelect;

  /// Una línea extra bajo un producto. Ej: «En tu venta: 2 u.».
  final String? Function(CatalogItem item)? noteFor;

  @override
  ConsumerState<CatalogBrowser> createState() => _CatalogBrowserState();
}

class _CatalogBrowserState extends ConsumerState<CatalogBrowser> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String? _categoryId;
  int _pages = 1;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// Espera a que se deje de escribir antes de buscar.
  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _query = text.trim();
          _pages = 1;
        });
      }
    });
  }

  CatalogPageQuery _pageQuery(int page) =>
      (search: _query, categoryId: _categoryId, page: page);

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(catalogCategoriesProvider).value ?? const [];
    final pages = [
      for (var page = 1; page <= _pages; page++)
        ref.watch(catalogPageProvider(_pageQuery(page))),
    ];
    final items = [for (final page in pages) ...?page.value?.items];
    final first = pages.first;
    final last = pages.last;

    return RefreshablePage(
      onRefresh: () {
        ref.invalidate(catalogCategoriesProvider);
        ref.invalidate(catalogPageProvider);
        return ref.read(catalogPageProvider(_pageQuery(1)).future);
      },
      children: [
        ...widget.header,
        const SizedBox(height: 12),
        TextField(
          controller: _search,
          onChanged: _onSearch,
          textInputAction: TextInputAction.search,
          autocorrect: false,
          style: AppText.body(16, FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Buscar por nombre o código',
            hintStyle: AppText.body(16, FontWeight.w400, color: AppColors.muted),
            prefixIcon: const Icon(Icons.search, color: AppColors.muted),
          ),
        ),
        const SizedBox(height: 4),
        UnderlineTabs<String?>(
          options: [(null, 'Todo'), for (final c in categories) (c.id, c.name)],
          selected: _categoryId,
          onSelected: (id) => setState(() {
            _categoryId = id;
            _pages = 1;
          }),
        ),
        const SizedBox(height: 4),
        if (items.isEmpty && first.isLoading)
          for (var i = 0; i < 4; i++) ...const [SizedBox(height: 8), SkeletonBlock(height: 72)]
        else if (items.isEmpty && first.hasError)
          ErrorPanel(
            message: errorMessage(first.error!),
            onRetry: () => ref.invalidate(catalogPageProvider(_pageQuery(1))),
          )
        else if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              _query.isEmpty
                  ? 'No hay productos en esta categoría.'
                  : 'No hay productos que coincidan con «$_query».',
              style: AppText.body(15, FontWeight.w400, color: AppColors.muted),
            ),
          )
        else ...[
          for (final item in items)
            _ProductRow(
              item: item,
              note: widget.noteFor?.call(item),
              detail: widget.detail,
              onTap: () => widget.onSelect(item),
            ),
          if (_pages > 1 && last.hasError) ...[
            const SizedBox(height: 8),
            ErrorPanel(
              message: errorMessage(last.error!),
              onRetry: () => ref.invalidate(catalogPageProvider(_pageQuery(_pages))),
            ),
          ] else if (last.isLoading) ...const [
            SizedBox(height: 8),
            SkeletonBlock(height: 72),
          ] else if (last.value?.hasMore ?? false) ...[
            const SizedBox(height: 12),
            CutButton(
              label: 'Ver más productos',
              height: 48,
              fontSize: 17,
              color: AppColors.ink,
              onPressed: () => setState(() => _pages++),
            ),
          ],
        ],
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.item,
    required this.onTap,
    required this.detail,
    this.note,
  });

  final CatalogItem item;
  final VoidCallback onTap;
  final ProductRowDetail detail;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final wholesale = item.priceWholesale;
    final note = this.note;
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.rule, width: 2)),
          ),
          child: Row(
            children: [
              ProductTile(category: item.category, imageUrl: item.imageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.itemCode, style: AppText.mono(11, color: AppColors.muted)),
                    const SizedBox(height: 1),
                    Text(item.name, style: AppText.body(16, FontWeight.w600, height: 1.15)),
                    const SizedBox(height: 3),
                    if (detail == ProductRowDetail.stock)
                      Text(
                        'En bodega ${item.stock} · reservado ${item.reserved}',
                        style: AppText.body(13, FontWeight.w400, color: AppColors.muted),
                      ),
                    if (detail == ProductRowDetail.prices) ...[
                      Text.rich(
                        TextSpan(
                          text: 'Minorista ',
                          children: [
                            TextSpan(
                              text: item.priceUnit.formatInline(),
                              style: AppText.body(13, FontWeight.w700),
                            ),
                          ],
                        ),
                        style: AppText.body(13, FontWeight.w400),
                      ),
                      if (wholesale != null)
                        Text(
                          'Mayorista ${wholesale.formatInline()} desde ${item.wholesaleMinQty} u.',
                          style: AppText.body(13, FontWeight.w400, color: AppColors.muted),
                        ),
                    ],
                    if (detail != ProductRowDetail.none) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.soldOut ? 'Agotado' : 'Disponible ${item.available}',
                        style: AppText.body(
                          13,
                          FontWeight.w700,
                          color: item.soldOut ? AppColors.alert : AppColors.violet,
                        ),
                      ),
                    ],
                    if (note != null)
                      Text(note, style: AppText.body(13, FontWeight.w600)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
