/// La bandeja de Jime: pagos, evidencias, cierres de caja y entregas por
/// validar. Nadie aprueba lo propio.
library;

import '../../../core/money/money.dart';
import '../../../core/network/json.dart';
import '../../orders/domain/orders.dart';
import '../../team/domain/kpi.dart';
import '../../team/domain/my_week.dart';
import '../../warehouse/domain/warehouse.dart';

enum PendingType {
  payment('payment', 'Pagos'),
  evidence('evidence', 'Evidencias'),
  cashClosing('cash_closing', 'Caja'),
  deliverable('deliverable', 'Entregas');

  const PendingType(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static PendingType fromApi(String value) => values.firstWhere((t) => t.apiValue == value);
}

class PendingItem {
  const PendingItem({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.createdAt,
    this.amount,
  });

  factory PendingItem.fromJson(Json json) => PendingItem(
        type: PendingType.fromApi(json.str('type')),
        id: json.str('id'),
        title: json.str('title'),
        subtitle: json.str('subtitle'),
        createdAt: json.date('created_at'),
        amount: json.moneyOrNull('amount'),
      );

  final PendingType type;

  /// Id del pago, del indicador semanal, del cierre o de la entrega.
  final String id;
  final String title;
  final String subtitle;
  final DateTime createdAt;
  final Money? amount;
}

/// Un comprobante por revisar. Que la referencia no se repita lo calcula el
/// servidor; el monto y la cuenta destino los confirma Jime.
class PaymentReview {
  const PaymentReview({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.customerName,
    required this.itemsLabel,
    required this.orderTotal,
    required this.method,
    required this.amount,
    required this.status,
    required this.referenceUnique,
    this.sellerName,
    this.reference,
    this.proofUrl,
    this.submittedAt,
    this.destinationAccount,
    this.rejectReason,
  });

  factory PaymentReview.fromJson(Json json) {
    final order = json.obj('order');
    return PaymentReview(
      id: json.str('id'),
      orderId: order.str('id'),
      orderNumber: order.str('number'),
      customerName: order.str('customer_name'),
      itemsLabel: order.str('items_label'),
      orderTotal: order.money('total'),
      sellerName: order.strOrNull('seller_name'),
      method: PaymentMethod.fromApi(json.str('method')),
      amount: json.money('amount'),
      status: PaymentStatus.fromApi(json.str('status')),
      referenceUnique: json.flag('reference_unique'),
      reference: json.strOrNull('reference'),
      proofUrl: json.strOrNull('proof_url'),
      submittedAt: json.dateOrNull('submitted_at'),
      destinationAccount: json.strOrNull('destination_account'),
      rejectReason: json.strOrNull('reject_reason'),
    );
  }

  final String id;
  final String orderId;
  final String orderNumber;
  final String customerName;
  final String? sellerName;
  final String itemsLabel;
  final Money orderTotal;
  final PaymentMethod method;
  final Money amount;
  final PaymentStatus status;
  final bool referenceUnique;
  final String? reference;
  final String? proofUrl;
  final DateTime? submittedAt;
  final String? destinationAccount;
  final String? rejectReason;

  bool get amountMatchesOrder => amount == orderTotal;
}

/// Un indicador con la evidencia que subió la persona, para cargar el valor
/// real o pedir otra.
class EvidenceReview {
  const EvidenceReview({
    required this.resultId,
    required this.memberId,
    required this.memberName,
    required this.weekLabel,
    required this.indicator,
    required this.howVerified,
    required this.unit,
    required this.evidence,
  });

  factory EvidenceReview.fromJson(Json json) {
    final member = json.obj('member');
    final indicator = json.obj('indicator');
    return EvidenceReview(
      resultId: json.str('result_id'),
      memberId: member.str('id'),
      memberName: member.str('name'),
      weekLabel: json.str('week_label'),
      indicator: KpiIndicator.fromJson(indicator),
      howVerified: indicator.str('how_verified'),
      unit: KpiUnit.fromApi(indicator.str('unit')),
      evidence: json.list('evidence').map(Evidence.fromJson).toList(),
    );
  }

  final String resultId;
  final String memberId;
  final String memberName;
  final String weekLabel;
  final KpiIndicator indicator;
  final String howVerified;
  final KpiUnit unit;
  final List<Evidence> evidence;
}

abstract interface class ReviewRepository {
  /// Lo más antiguo primero.
  Future<List<PendingItem>> pending({PendingType? type});

  Future<PaymentReview> payment(String id);

  /// Confirma el cobro: el pedido pasa a «Pagado» y cuenta para el bono de la
  /// semana en que llegó el dinero ([receivedAt]; si no se indica, cuando se
  /// subió el comprobante).
  Future<PaymentReview> confirmPayment(
    String id, {
    required bool amountMatches,
    required bool destinationOk,
    DateTime? receivedAt,
  });

  Future<PaymentReview> rejectPayment(String id, {required String reason});

  Future<EvidenceReview> evidence(String resultId);

  /// Valida la evidencia y carga el valor real.
  Future<EvidenceReview> validateResult(String resultId, {required double actual, String? note});

  /// Pide otra evidencia, explicando por qué.
  Future<EvidenceReview> observeResult(String resultId, {required String note});

  Future<CashDay> cashClosing(String id);

  Future<CashDay> validateCashClosing(String id);

  Future<CashDay> observeCashClosing(String id, {required String note});

  /// Las 8 entregas de Sistemas.
  Future<List<Deliverable>> deliverables();

  Future<Deliverable> validateDeliverable(String id, {required DateTime deliveredOn});

  Future<Deliverable> rejectDeliverable(String id, {required String note});

  /// Devolución: revierte el cobro, ajusta la comisión y, si ya se había
  /// entregado, devuelve el stock.
  Future<void> returnOrder(String orderId, {required String reason});

  /// Venta registrada dos veces: se anula esta y queda ligada a la original.
  Future<void> markDuplicate(String orderId, {required String originalOrderId});
}
