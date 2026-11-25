import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/app/app_bottom_bar.dart';
import 'package:traigo/core/media/photo_picker.dart';
import 'package:traigo/core/network/upload_file.dart';

import 'test_app.dart';

/// Abre la app ya ingresada con [code] y va a la pestaña [tab].
Future<void> openTab(
  WidgetTester tester,
  String code,
  String? tab, {
  double width = 390,
  double height = 1000,
  List<Override> overrides = const [],
}) async {
  useMobileScreen(tester, width: width, height: height);
  await tester.pumpWidget(testApp(tokens: signedInTokens(code), overrides: overrides));
  await tester.pumpAndSettle();
  if (tab != null) await tapTab(tester, tab);
}

Future<void> openCatalog(WidgetTester tester, String code, {double height = 1000}) =>
    openTab(tester, code, 'Catálogo', height: height);

Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(AppBottomBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

/// Escribe en el buscador y espera a que busque.
Future<void> search(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).first, text);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
}

/// El campo que está debajo de la etiqueta [label].
Finder field(String label) => find.descendant(
      of: find.byKey(ValueKey('field-$label')),
      matching: find.byType(TextField),
    );

/// Devuelve siempre la misma foto (o nada) y anota de dónde se pidió.
class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker({this.file, this.error});

  UploadFile? file;
  Object? error;
  final List<PhotoSource> sources = [];

  @override
  Future<UploadFile?> pick(PhotoSource source) async {
    sources.add(source);
    final error = this.error;
    if (error != null) throw error;
    return file;
  }
}
