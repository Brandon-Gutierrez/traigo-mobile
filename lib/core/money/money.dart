import 'package:flutter/foundation.dart';

/// Monto en bolivianos guardado en centavos (entero), para no arrastrar
/// errores de redondeo de `double`.
///
/// Con el backend viaja como texto con dos decimales: `"120.00"`.
@immutable
class Money implements Comparable<Money> {
  const Money.fromCents(this.cents);

  /// Acepta `"120"`, `"120.5"` o `"-12.34"`.
  factory Money.parse(String raw) {
    final match = RegExp(r'^(-?)(\d+)(?:\.(\d{1,2}))?$').firstMatch(raw.trim());
    if (match == null) {
      throw FormatException('Monto inválido: "$raw"');
    }
    final sign = match.group(1) == '-' ? -1 : 1;
    final whole = int.parse(match.group(2)!);
    final fraction = int.parse((match.group(3) ?? '0').padRight(2, '0'));
    return Money.fromCents(sign * (whole * 100 + fraction));
  }

  /// Tolerante con lo que mande el backend: texto, entero (Bs) o decimal.
  factory Money.fromJson(Object? value) {
    return switch (value) {
      String s => Money.parse(s),
      int n => Money.fromCents(n * 100),
      double d => Money.fromCents((d * 100).round()),
      _ => throw FormatException('Monto inválido en la respuesta: $value'),
    };
  }

  static const zero = Money.fromCents(0);

  final int cents;

  bool get isZero => cents == 0;
  bool get isNegative => cents < 0;

  Money operator +(Money other) => Money.fromCents(cents + other.cents);
  Money operator -(Money other) => Money.fromCents(cents - other.cents);
  Money operator *(int times) => Money.fromCents(cents * times);

  bool operator <(Money other) => cents < other.cents;
  bool operator <=(Money other) => cents <= other.cents;
  bool operator >(Money other) => cents > other.cents;
  bool operator >=(Money other) => cents >= other.cents;

  /// Proporción del monto (por ejemplo 0.40 = 40 %), redondeada al centavo.
  Money percent(double rate) => Money.fromCents((cents * rate).round());

  /// Formato que viaja al backend: `"86.40"`.
  String toApi() {
    final abs = cents.abs();
    final fraction = (abs % 100).toString().padLeft(2, '0');
    return '${cents < 0 ? '-' : ''}${abs ~/ 100}.$fraction';
  }

  /// Formato de pantalla: `Bs 120`, `Bs 86,40`, `Bs 1.340`.
  /// Los montos enteros no llevan decimales, igual que en el diseño.
  String format({bool symbol = true}) => _format(symbol: symbol, fixed: false);

  /// Siempre con dos decimales: `Bs 1.340,00`.
  String formatFixed({bool symbol = true}) => _format(symbol: symbol, fixed: true);

  /// Como [format], pero con espacio fijo: dentro de una frase «Bs» no se
  /// separa de la cifra.
  String formatInline() => format().replaceFirst(' ', String.fromCharCode(0xA0));

  String _format({required bool symbol, required bool fixed}) {
    final abs = cents.abs();
    final whole = _group(abs ~/ 100);
    final fraction = abs % 100;
    final body = (fraction == 0 && !fixed)
        ? whole
        : '$whole,${fraction.toString().padLeft(2, '0')}';
    return '${cents < 0 ? '−' : ''}${symbol ? 'Bs ' : ''}$body';
  }

  static String _group(int n) => n.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => '.',
      );

  @override
  int compareTo(Money other) => cents.compareTo(other.cents);

  @override
  bool operator ==(Object other) => other is Money && other.cents == cents;

  @override
  int get hashCode => cents.hashCode;

  @override
  String toString() => 'Money($cents)';
}
