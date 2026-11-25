/// KPI semanal individual, tal como se calcula en el Excel de Jime: cada
/// indicador avanza hasta 100 % como máximo (los excesos no compensan) y se
/// pondera por su peso. Si falta cargar alguno, el resultado queda pendiente.
library;

import '../../../core/network/json.dart';
import 'bonus.dart';

enum EvidenceStatus {
  missing('missing', 'Sin evidencia'),
  inReview('in_review', 'En revisión'),
  validated('validated', 'Validada'),
  observed('observed', 'Observada');

  const EvidenceStatus(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static EvidenceStatus fromApi(String value) =>
      values.firstWhere((s) => s.apiValue == value);
}

class KpiIndicator {
  const KpiIndicator({
    required this.id,
    required this.name,
    required this.target,
    required this.weight,
    required this.evidence,
    this.actual,
  });

  factory KpiIndicator.fromJson(Json json) => KpiIndicator(
        id: json.str('id'),
        name: json.str('name'),
        target: (json['target'] as num).toDouble(),
        actual: (json['actual'] as num?)?.toDouble(),
        weight: json.rate('weight'),
        evidence: EvidenceStatus.fromApi(json.str('evidence_status')),
      );

  final String id;
  final String name;

  /// Meta de la semana (ya ajustada en la primera y la última semana).
  final double target;

  /// Valor real que cargó Jime. `null` = todavía sin cargar.
  final double? actual;

  /// 0.25 = pesa 25 % del puntaje.
  final double weight;
  final EvidenceStatus evidence;

  /// Avance de 0 a 1; nunca más de 1.
  double get progress {
    final value = actual;
    if (value == null || target <= 0) return 0;
    return (value / target).clamp(0, 1).toDouble();
  }
}

abstract final class KpiRules {
  /// Puntaje de 0 a 1 con lo cargado hasta ahora.
  static double score(Iterable<KpiIndicator> indicators) => indicators.fold(
        0,
        (total, i) => total + i.weight * i.progress,
      );

  /// Puntaje en % entero, redondeado hacia abajo: 89,9 % no llega a 90 %.
  static int scorePercent(Iterable<KpiIndicator> indicators) =>
      (score(indicators) * 100 + 1e-9).floor();

  /// Pendiente si falta cargar algún indicador o si queda una entrega sin
  /// resolver. [deliverables] es el estado de las entregas que pide la semana:
  /// `fails` si alguna llegó tarde o Jime no la validó.
  static Compliance compliance(
    Iterable<KpiIndicator> indicators, {
    required int minimumPercent,
    Compliance deliverables = Compliance.passes,
  }) {
    if (indicators.any((i) => i.actual == null) || deliverables == Compliance.pending) {
      return Compliance.pending;
    }
    if (deliverables == Compliance.fails) return Compliance.fails;
    return scorePercent(indicators) >= minimumPercent ? Compliance.passes : Compliance.fails;
  }
}
