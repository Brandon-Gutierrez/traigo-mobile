/// «Mi semana»: KPI con su evidencia y las entregas de Sistemas.
library;

import '../../../core/network/json.dart';
import '../../../core/network/upload_file.dart';
import 'bonus.dart';
import 'kpi.dart';

export '../../../core/network/upload_file.dart';

enum KpiUnit {
  count('count'),
  percent('percent');

  const KpiUnit(this.apiValue);
  final String apiValue;

  static KpiUnit fromApi(String value) => values.firstWhere((u) => u.apiValue == value);
}

enum EvidenceKind {
  photo('photo', 'Foto'),
  link('link', 'Enlace'),
  order('order', 'Pedido');

  const EvidenceKind(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static EvidenceKind fromApi(String value) => values.firstWhere((k) => k.apiValue == value);
}

class Evidence {
  const Evidence({
    required this.id,
    required this.kind,
    required this.status,
    required this.submittedAt,
    this.url,
    this.orderId,
    this.orderNumber,
    this.note,
    this.reviewNote,
  });

  factory Evidence.fromJson(Json json) => Evidence(
        id: json.str('id'),
        kind: EvidenceKind.fromApi(json.str('kind')),
        status: EvidenceStatus.fromApi(json.str('status')),
        submittedAt: json.date('submitted_at'),
        url: json.strOrNull('url'),
        orderId: json.strOrNull('order_id'),
        orderNumber: json.strOrNull('order_number'),
        note: json.strOrNull('note'),
        reviewNote: json.strOrNull('review_note'),
      );

  final String id;
  final EvidenceKind kind;
  final EvidenceStatus status;
  final DateTime submittedAt;
  final String? url;
  final String? orderId;
  final String? orderNumber;
  final String? note;

  /// Por qué Jime la observó.
  final String? reviewNote;
}

/// Evidencia que se va a enviar: una foto, un enlace o un pedido.
class NewEvidence {
  const NewEvidence.photo({required this.clientUuid, required UploadFile this.file, this.note})
      : kind = EvidenceKind.photo,
        url = null,
        orderId = null;

  const NewEvidence.link({required this.clientUuid, required String this.url, this.note})
      : kind = EvidenceKind.link,
        file = null,
        orderId = null;

  const NewEvidence.order({required this.clientUuid, required String this.orderId, this.note})
      : kind = EvidenceKind.order,
        file = null,
        url = null;

  final String clientUuid;
  final EvidenceKind kind;
  final UploadFile? file;
  final String? url;
  final String? orderId;
  final String? note;

  Map<String, Object?> get fields =>
      {'kind': kind.apiValue, 'url': url, 'order_id': orderId, 'note': note};
}

/// Un indicador de mi semana. [indicator] trae meta, valor real y peso; su
/// `id` es el del resultado semanal (el que se usa para subir evidencia).
class WeekIndicator {
  const WeekIndicator({
    required this.indicator,
    required this.howVerified,
    required this.unit,
    required this.evidence,
  });

  factory WeekIndicator.fromJson(Json json) => WeekIndicator(
        indicator: KpiIndicator.fromJson(json),
        howVerified: json.str('how_verified'),
        unit: KpiUnit.fromApi(json.str('unit')),
        evidence: json.list('evidence').map(Evidence.fromJson).toList(),
      );

  final KpiIndicator indicator;
  final String howVerified;
  final KpiUnit unit;
  final List<Evidence> evidence;
}

enum DeliverableStatus {
  /// Todavía no se envió.
  pending('pending', 'Pendiente'),

  /// Enviada con evidencia; falta que Jime la valide.
  inReview('in_review', 'En revisión'),
  notValidated('not_validated', 'No validada'),
  onTime('on_time', 'Validada'),
  late('late', 'Fuera de plazo');

  const DeliverableStatus(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static DeliverableStatus fromApi(String value) =>
      values.firstWhere((s) => s.apiValue == value);
}

class Deliverable {
  const Deliverable({
    required this.id,
    required this.title,
    required this.acceptanceTest,
    required this.dueOn,
    required this.status,
    this.memberId,
    this.memberName,
    this.deliveredOn,
    this.evidenceUrl,
    this.reviewNote,
  });

  factory Deliverable.fromJson(Json json) => Deliverable(
        id: json.str('id'),
        title: json.str('title'),
        acceptanceTest: json.str('acceptance_test'),
        dueOn: json.date('due_on'),
        status: DeliverableStatus.fromApi(json.str('status')),
        memberId: json.strOrNull('member_id'),
        memberName: json.strOrNull('member_name'),
        deliveredOn: json.dateOrNull('delivered_on'),
        evidenceUrl: json.strOrNull('evidence_url'),
        reviewNote: json.strOrNull('review_note'),
      );

  final String id;
  final String title;
  final String acceptanceTest;
  final DateTime dueOn;
  final DeliverableStatus status;
  final String? memberId;
  final String? memberName;

  /// Fecha real de entrega.
  final DateTime? deliveredOn;
  final String? evidenceUrl;
  final String? reviewNote;
}

class MyWeek {
  const MyWeek({
    required this.week,
    required this.weekNumber,
    required this.countTargetFactor,
    required this.partialScorePercent,
    required this.minimumPercent,
    required this.compliance,
    required this.indicators,
    required this.deliverables,
    this.scorePercent,
    this.closedReason,
  });

  factory MyWeek.fromJson(Json json) {
    final week = json.obj('week');
    return MyWeek(
      week: BonusWeek.fromJson(week),
      weekNumber: week.integer('number'),
      countTargetFactor: json.rate('count_target_factor'),
      scorePercent: json.integerOrNull('score_percent'),
      partialScorePercent: json.integer('partial_score_percent'),
      minimumPercent: json.integer('minimum_percent'),
      compliance: Compliance.fromApi(json.str('compliance')),
      indicators: json.list('indicators').map(WeekIndicator.fromJson).toList(),
      deliverables: json.list('deliverables').map(Deliverable.fromJson).toList(),
      closedReason: json.strOrNull('closed_reason'),
    );
  }

  final BonusWeek week;
  final int weekNumber;

  /// 0.9 en la primera semana: las metas de cantidad están reducidas.
  final double countTargetFactor;

  /// `null` mientras falte cargar algún indicador.
  final int? scorePercent;

  /// Avance con lo cargado hasta ahora.
  final int partialScorePercent;
  final int minimumPercent;
  final Compliance compliance;
  final List<WeekIndicator> indicators;

  /// Solo Sistemas en la semana que pide entregas.
  final List<Deliverable> deliverables;

  /// Motivo, si Jime cerró esta semana como «no cumple».
  final String? closedReason;
}
