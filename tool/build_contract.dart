/// Regenera docs/api-contract.md:
///
///     dart tool/build_contract.dart
library;

import 'dart:io';

import 'contract_builder.dart';

void main() {
  final template = File('tool/api-contract.template.md').readAsStringSync();
  File('docs/api-contract.md').writeAsStringSync(buildContract(template));
  stdout.writeln('docs/api-contract.md actualizado.');
}
