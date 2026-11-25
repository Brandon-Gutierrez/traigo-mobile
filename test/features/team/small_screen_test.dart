import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/app/router.dart';
import 'package:traigo/core/media/photo_picker.dart';
import 'package:traigo/core/network/upload_file.dart';

import '../../support/sales_helpers.dart';
import '../../support/test_app.dart';

/// Ninguna pantalla de la fase 3 debe desbordar en un celular de 320 de ancho
/// con la letra agrandada.
void main() {
  const long = UploadFile(
    path: '/no/existe/foto.jpg',
    filename: 'informe-semanal-de-contenido-y-lives-1-6-diciembre.jpg',
  );

  Future<void> openSmall(WidgetTester tester, String code, String route) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openTab(tester, code, null, width: 320, height: 640, overrides: [
      photoPickerProvider.overrideWithValue(FakePhotoPicker(file: long)),
    ]);
    containerOf(tester).read(routerProvider).go(route);
    await tester.pumpAndSettle();
  }

  Future<void> scrollThrough(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -350));
      await tester.pumpAndSettle();
    }
  }

  final screens = {
    'mi semana de Alison': ('ALI-04', AppRoutes.week),
    'mi semana de Isaí': ('ISA-03', AppRoutes.week),
    'mi semana de Sistemas': ('SIS-06', AppRoutes.week),
    'evidencia de Ailén': ('AIL-02', AppRoutes.evidence),
    'evidencia de Sistemas': ('SIS-06', AppRoutes.evidence),
    'equipo': ('SIS-07', AppRoutes.team),
    'indicador con evidencia': ('ALI-04', AppRoutes.indicator(AppRoutes.week, '4-4')),
    'indicador observado': ('AIL-02', AppRoutes.indicator(AppRoutes.evidence, '2-3')),
    'indicador validado': ('ALI-04', AppRoutes.indicator(AppRoutes.week, '4-3')),
    'entrega por enviar': ('SIS-06', AppRoutes.deliverable(AppRoutes.week, 'd-3')),
    'entrega enviada': ('SIS-06', AppRoutes.deliverable(AppRoutes.evidence, 'd-2')),
    'entrega validada': ('SIS-07', AppRoutes.deliverable(AppRoutes.week, 'd-7')),
  };

  for (final MapEntry(key: name, value: (code, route)) in screens.entries) {
    testWidgets('$name cabe en 320 de ancho con letra grande', (tester) async {
      await openSmall(tester, code, route);
      await scrollThrough(tester);

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('con una foto elegida y con un pedido elegido también cabe',
      (tester) async {
    await openSmall(tester, 'ALI-04', AppRoutes.indicator(AppRoutes.week, '4-4'));

    await scrollUntil(tester, find.text('Elegir de la galería'));
    await tester.tap(find.text('Elegir de la galería'));
    await tester.pumpAndSettle();
    await scrollThrough(tester);
    expect(tester.takeException(), isNull);

    await scrollUntil(tester, find.text('Pedido'), up: true);
    await tester.tap(find.text('Pedido'));
    await tester.pumpAndSettle();
    await scrollUntil(tester, find.text('Elegir pedido'));
    await tester.tap(find.text('Elegir pedido'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('N-1046'));
    await tester.pumpAndSettle();
    await scrollThrough(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('el calendario de la entrega cabe', (tester) async {
    await openSmall(tester, 'SIS-06', AppRoutes.deliverable(AppRoutes.week, 'd-3'));

    await scrollUntil(tester, find.text('06/12/2026'));
    await tester.tap(find.text('06/12/2026'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
