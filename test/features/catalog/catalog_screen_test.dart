import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/app/app_bottom_bar.dart';
import 'package:traigo/features/catalog/presentation/catalog_browser.dart';

import '../../support/sales_helpers.dart';
import '../../support/test_app.dart';

void main() {
  testWidgets('todo el equipo ve el catálogo, de 30 en 30', (tester) async {
    // Alto suficiente para que la lista construya los 62 productos.
    await openCatalog(tester, 'ISA-03', height: 12000);

    expect(find.text('62 productos'), findsOneWidget);
    expect(find.text('Arma de disparo azul'), findsOneWidget);
    expect(find.text('Tomatodos de Messi'), findsNothing, reason: 'está en la página 3');

    await scrollAndTap(tester, find.text('Ver más productos'));
    await scrollAndTap(tester, find.text('Ver más productos'));

    expect(find.text('Tomatodos de Messi'), findsOneWidget);
    expect(find.text('Ver más productos'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtra por categoría y busca sin tildes', (tester) async {
    await openCatalog(tester, 'ISA-03');

    await tester.tap(find.text('Juguetes'));
    await tester.pumpAndSettle();
    expect(find.text('Arma de disparo azul'), findsOneWidget);
    expect(find.text('Maceta café grande'), findsNothing);

    await tester.tap(find.text('Todo'));
    await search(tester, 'ceramica de barro');
    expect(find.text('Maceta tipo cerámica de barro, extra grande'), findsOneWidget);

    await search(tester, 'zzz');
    expect(find.text('No hay productos que coincidan con «zzz».'), findsOneWidget);
  });

  testWidgets('cada producto muestra precios y si está agotado', (tester) async {
    await openCatalog(tester, 'ISA-03');
    await search(tester, 'dream');

    expect(findTextContaining('Mayorista Bs 82 desde 24 u.'), findsOneWidget);
    expect(find.text('Disponible 48'), findsOneWidget);
    expect(find.text('Agotado'), findsOneWidget);
  });

  testWidgets('la ficha de quien no vende no tiene comisión ni botón', (tester) async {
    await openCatalog(tester, 'ISA-03');
    await search(tester, '8107');
    await scrollAndTap(tester, find.text('Tomatodos de Messi'));

    expect(find.text('8107 · TOMATODOS'), findsOneWidget);
    expect(find.text('Minorista (1 unidad)'), findsOneWidget);
    expect(find.text('Mayorista, desde 24 u.'), findsOneWidget);
    expect(find.text('45 u.'), findsOneWidget);
    expect(find.text('TU COMISIÓN'), findsNothing);
    expect(find.text('Agregar a la venta'), findsNothing);

    await tester.tap(find.text('Catálogo').first);
    await tester.pumpAndSettle();
    expect(find.byType(CatalogBrowser), findsOneWidget);
  });

  testWidgets('quien vende agrega desde la ficha y ve que ya está', (tester) async {
    await openCatalog(tester, 'ALI-04', height: 1400);
    await search(tester, '8107');
    await scrollAndTap(tester, find.text('Tomatodos de Messi'));

    expect(find.text('[% por definir]'), findsOneWidget);
    await scrollAndTap(tester, find.text('Agregar a la venta'));
    expect(find.text('PASO 1 DE 2 · PRODUCTOS'), findsOneWidget);
    expect(find.text('Tomatodos de Messi'), findsOneWidget);

    await tester.tap(
      find.descendant(of: find.byType(AppBottomBar), matching: find.text('Catálogo')),
    );
    await tester.pumpAndSettle();
    expect(find.text('En tu venta (1 u.) · ver'), findsOneWidget);
  });

  testWidgets('un producto agotado no se puede agregar', (tester) async {
    await openCatalog(tester, 'ALI-04', height: 1400);
    await search(tester, 'A393880');
    await scrollAndTap(tester, find.text('Auto en PVC verde'));

    expect(find.text('Agotado'), findsOneWidget);
    expect(find.text('Agregar a la venta'), findsNothing);
  });
}
