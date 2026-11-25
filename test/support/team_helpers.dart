import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/core/ui/form_pieces.dart';

/// El bloque del indicador [name] en «Mi semana».
Finder indicatorBlock(String name) => find.byKey(ValueKey('indicator-$name'));

/// El enlace «volver a [label]» de arriba.
Finder backTo(String label) =>
    find.descendant(of: find.byType(BackLink), matching: find.text(label));
