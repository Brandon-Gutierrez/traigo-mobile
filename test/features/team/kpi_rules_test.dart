import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/features/team/domain/bonus.dart';
import 'package:traigo/features/team/domain/kpi.dart';

/// Cálculo del KPI individual, igual que en el Excel de Jime.
KpiIndicator indicator(double target, double? actual, double weight) => KpiIndicator(
      id: '$target-$weight',
      name: 'Indicador',
      target: target,
      actual: actual,
      weight: weight,
      evidence: EvidenceStatus.validated,
    );

void main() {
  test('superar una meta no compensa otra que quedó corta', () {
    final list = [indicator(10, 20, 0.5), indicator(10, 5, 0.5)];
    expect(KpiRules.scorePercent(list), 75);
  });

  test('89,9 % no llega a un mínimo de 90 %', () {
    final list = [indicator(1000, 899, 1)];
    expect(KpiRules.scorePercent(list), 89);
    expect(KpiRules.compliance(list, minimumPercent: 90), Compliance.fails);
  });

  test('un 90 % exacto sí llega, aunque el decimal no sea exacto', () {
    final list = [
      indicator(1, 1, 0.3),
      indicator(1, 1, 0.3),
      indicator(1, 1, 0.3),
      indicator(1, 0, 0.1),
    ];
    expect(KpiRules.scorePercent(list), 90);
    expect(KpiRules.compliance(list, minimumPercent: 90), Compliance.passes);
  });

  test('si falta cargar un valor real, el resultado queda pendiente', () {
    final list = [indicator(10, 10, 0.9), indicator(10, null, 0.1)];
    expect(KpiRules.scorePercent(list), 90);
    expect(KpiRules.compliance(list, minimumPercent: 80), Compliance.pending);
  });

  test('con entregas sin validar queda pendiente aunque el puntaje alcance', () {
    final list = [indicator(1, 1, 1)];
    expect(
      KpiRules.compliance(list, minimumPercent: 90, deliverables: Compliance.pending),
      Compliance.pending,
    );
  });

  test('con una entrega tarde o sin validar no cumple aunque el puntaje alcance', () {
    final list = [indicator(1, 1, 1)];
    expect(
      KpiRules.compliance(list, minimumPercent: 90, deliverables: Compliance.fails),
      Compliance.fails,
    );
  });

  test('una meta en cero no divide por cero', () {
    expect(indicator(0, 3, 1).progress, 0);
  });
}
