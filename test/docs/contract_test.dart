import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract_builder.dart';

void main() {
  String read(String path) => File(path).readAsStringSync().replaceAll('\r\n', '\n');

  test('el contrato está al día con los ejemplos probados', () {
    expect(
      read('docs/api-contract.md'),
      buildContract(read('tool/api-contract.template.md')),
      reason: 'Corre: dart tool/build_contract.dart',
    );
  });

  test('el contrato menciona todas las rutas de la app', () {
    final doc = read('docs/api-contract.md');
    final paths = RegExp(r"'(/[^']*)'")
        .allMatches(read('lib/core/network/api_paths.dart'))
        // Las partes variables se escriben {así} en el documento.
        .map((m) => m.group(1)!.replaceAll(RegExp(r'\$\w+'), '{}'))
        .toSet();
    final documented = RegExp(r'`(?:GET|POST) (/[^`?]*)')
        .allMatches(doc)
        .map((m) => m.group(1)!.trim().replaceAll(RegExp(r'\{\w+\}'), '{}'))
        .toSet();

    expect(paths.difference(documented), isEmpty);
  });
}
