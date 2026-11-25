import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/app/router.dart';
import 'package:traigo/core/network/upload_file.dart';
import 'package:traigo/core/media/photo_picker.dart';

import '../../support/sales_helpers.dart';
import '../../support/test_app.dart';

void main() {
  late FakePhotoPicker picker;

  setUp(() {
    picker = FakePhotoPicker(
      file: const UploadFile(path: '/no/existe/foto.jpg', filename: 'foto.jpg'),
    );
  });

  Future<void> openOrders(WidgetTester tester, {String code = 'ALI-04'}) async {
    await openTab(
      tester,
      code,
      null,
      height: 1500,
      overrides: [photoPickerProvider.overrideWithValue(picker)],
    );
    await scrollAndTap(tester, find.text('Ver todas'));
  }

  Future<void> openOrder(WidgetTester tester, String customer) async {
    await openOrders(tester);
    await scrollAndTap(tester, find.text(customer));
  }

  testWidgets('«Mis pedidos» muestra solo los míos con su fecha y estado', (tester) async {
    await openOrders(tester);

    expect(find.text('Solo se ven los que registraste tú'), findsOneWidget);
    expect(find.text('N-1046  11:09'), findsOneWidget);
    expect(find.text('N-1040  Ayer'), findsOneWidget);
    expect(find.text('N-1038  1 dic'), findsOneWidget);
    expect(find.textContaining('N-1043'), findsNothing, reason: 'es de Kim');
    expect(find.text('Comprobante en revisión'), findsOneWidget);
    expect(find.text('Cancelado'), findsOneWidget);
  });

  testWidgets('las pestañas filtran por estado', (tester) async {
    await openOrders(tester);

    await scrollAndTap(tester, find.text('En revisión'));
    expect(find.textContaining('N-104'), findsOneWidget);

    await scrollAndTap(tester, find.text('Por pagar'));
    expect(find.text('No tienes pedidos en «Por pagar».'), findsOneWidget);
  });

  testWidgets('el detalle muestra avance, productos, pago y comisión', (tester) async {
    await openOrder(tester, 'Mariela Quispe');

    expect(find.text('N-1046 · HOY 11:09'), findsOneWidget);
    expect(find.text('REGISTRADO'), findsOneWidget);
    expect(find.text('PAGO CONFIRMADO'), findsOneWidget);
    expect(findTextContaining('2 × Bs 87 · minorista'), findsOneWidget);
    expect(find.text('comprobante-qr.jpg'), findsOneWidget);
    expect(find.text('Subido Hoy 11:25'), findsOneWidget);
    expect(find.text('Pendiente hasta que se cobre'), findsOneWidget);
    expect(find.text('[% por definir]'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cambiar el comprobante: elegir, revisar y enviar', (tester) async {
    await openOrder(tester, 'Mariela Quispe');

    await scrollAndTap(tester, find.text('Cambiar'));
    await tester.tap(find.text('Elegir de la galería'));
    await tester.pumpAndSettle();

    expect(picker.sources, [PhotoSource.gallery]);
    expect(find.text('Revisa la foto'), findsOneWidget);
    await tester.enterText(field('Número de referencia (opcional)'), '0045-8812');
    await tester.tap(find.text('Enviar a Jime'));
    await tester.pumpAndSettle();

    expect(find.text('Comprobante enviado. Jime lo va a revisar.'), findsOneWidget);
    expect(find.text('foto.jpg'), findsOneWidget);
    expect(find.text('0045-8812'), findsOneWidget);
  });

  testWidgets('si se arrepiente de la foto, no cambia nada', (tester) async {
    picker.file = null;
    await openOrder(tester, 'Mariela Quispe');

    await scrollAndTap(tester, find.text('Cambiar'));
    await tester.tap(find.text('Tomar foto'));
    await tester.pumpAndSettle();

    expect(picker.sources, [PhotoSource.camera]);
    expect(find.text('Revisa la foto'), findsNothing);
    expect(find.text('comprobante-qr.jpg'), findsOneWidget);
  });

  testWidgets('sin permiso para la cámara lo explica', (tester) async {
    picker.error = PlatformException(code: 'camera_access_denied');
    await openOrder(tester, 'Mariela Quispe');

    await scrollAndTap(tester, find.text('Cambiar'));
    await tester.tap(find.text('Tomar foto'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo abrir la cámara. Revisa los permisos de la app.'),
        findsOneWidget);
  });

  testWidgets('cancelar pide confirmación y devuelve el stock', (tester) async {
    await openOrder(tester, 'Mariela Quispe');

    await scrollAndTap(tester, find.text('Cancelar pedido'));
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('Comprobante en revisión'), findsOneWidget);

    await scrollAndTap(tester, find.text('Cancelar pedido'));
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar pedido'));
    await tester.pumpAndSettle();

    expect(find.text('Pedido N-1046 cancelado.'), findsOneWidget);
    expect(find.text('Cancelado'), findsOneWidget);
    expect(find.text('Cancelar pedido'), findsNothing);
    expect(find.text('REGISTRADO'), findsNothing);

    await tapTab(tester, 'Catálogo');
    await search(tester, '8107');
    expect(find.text('Disponible 47'), findsOneWidget);
  });

  testWidgets('un pedido en efectivo no pide comprobante', (tester) async {
    await openOrder(tester, 'Rosa Mamani');

    expect(find.text('Subir comprobante'), findsNothing);
    expect(find.text('Cancelar pedido'), findsNothing);
    expect(find.text('Jime confirmó el pago.'), findsOneWidget);
  });

  testWidgets('desde el Inicio se abre una venta de hoy', (tester) async {
    await openTab(tester, 'ALI-04', null, height: 1500);

    await scrollAndTap(tester, find.text('Valeria Paz · QR'));

    expect(find.text('N-1045 · HOY 10:41'), findsOneWidget);
  });

  testWidgets('quien no vende no entra a pedidos', (tester) async {
    await openTab(tester, 'ISA-03', null);
    final router = containerOf(tester).read(routerProvider);

    for (final route in [AppRoutes.orders, AppRoutes.order('1046'), AppRoutes.sellCustomer]) {
      router.go(route);
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, AppRoutes.home,
          reason: route);
    }
    router.go(AppRoutes.product('p-8107'));
    await tester.pumpAndSettle();
    expect(find.text('8107 · TOMATODOS'), findsOneWidget);
  });
}
