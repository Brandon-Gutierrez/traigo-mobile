import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/core/money/money.dart';

void main() {
  test('lee los montos como se escriben en Bolivia', () {
    for (final (text, cents) in const [
      ('810', 81000),
      ('810,50', 81050),
      ('810.5', 81050),
      ('1.340', 134000),
      ('1.340,5', 134050),
      ('Bs 2.140', 214000),
      ('0', 0),
    ]) {
      expect(Money.tryParseInput(text)?.cents, cents, reason: text);
    }
    for (final text in const ['', 'diez', '-5', '1,234', '12.3456', '1..2']) {
      expect(Money.tryParseInput(text), isNull, reason: text);
    }
  });

  group('Money.parse y toApi', () {
    test('lee montos del backend con y sin decimales', () {
      expect(Money.parse('120.00').cents, 12000);
      expect(Money.parse('86.4').cents, 8640);
      expect(Money.parse('1340').cents, 134000);
      expect(Money.parse('-12.34').cents, -1234);
    });

    test('rechaza texto que no es un monto', () {
      expect(() => Money.parse('12,50'), throwsFormatException);
      expect(() => Money.parse('abc'), throwsFormatException);
      expect(() => Money.parse('1.234'), throwsFormatException);
    });

    test('toApi vuelve al formato del contrato', () {
      expect(const Money.fromCents(8640).toApi(), '86.40');
      expect(const Money.fromCents(12000).toApi(), '120.00');
      expect(const Money.fromCents(5).toApi(), '0.05');
      expect(const Money.fromCents(-1234).toApi(), '-12.34');
    });

    test('fromJson acepta texto, entero y decimal', () {
      expect(Money.fromJson('3.20').cents, 320);
      expect(Money.fromJson(120).cents, 12000);
      expect(Money.fromJson(86.4).cents, 8640);
      expect(() => Money.fromJson(null), throwsFormatException);
    });
  });

  group('formato en pantalla', () {
    test('los montos enteros no llevan decimales', () {
      expect(Money.parse('120').format(), 'Bs 120');
      expect(Money.parse('1080').format(), 'Bs 1.080');
    });

    test('los montos con centavos llevan dos decimales y coma', () {
      expect(Money.parse('86.4').format(), 'Bs 86,40');
      expect(Money.parse('1983.33').format(), 'Bs 1.983,33');
    });

    test('formatFixed siempre muestra decimales', () {
      expect(Money.parse('1340').formatFixed(), 'Bs 1.340,00');
      expect(Money.parse('3860').formatFixed(symbol: false), '3.860,00');
    });

    test('los negativos usan el signo menos tipográfico', () {
      expect(Money.parse('-5').format(), '−Bs 5');
    });
  });

  group('operaciones', () {
    test('suma, resta y multiplica por cantidad', () {
      expect((Money.parse('10.50') + Money.parse('0.50')).cents, 1100);
      expect((Money.parse('120') - Money.parse('90')).cents, 3000);
      expect((Money.parse('85') * 3).cents, 25500);
    });

    test('percent redondea al centavo', () {
      expect(Money.parse('8').percent(0.40).toApi(), '3.20');
      expect(Money.parse('50').percent(0.25).toApi(), '12.50');
      expect(Money.parse('0.03').percent(0.5).cents, 2); // 1.5 → 2
    });

    test('compara y ordena', () {
      expect(Money.parse('90') < Money.parse('90.01'), isTrue);
      expect(Money.parse('90') >= Money.parse('90'), isTrue);
      expect(Money.parse('90'), Money.fromCents(9000));
    });
  });
}
