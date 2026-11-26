/// El panel de Jime y las autorizaciones de Dirección en la demo: bandeja,
/// validaciones, cierre semanal, bono, comisiones, precios, historial y
/// accesos. Aplica las reglas del contrato (docs/api-contract.md).
library;

import '../../features/auth/domain/auth.dart';
import '../../features/control/domain/admin.dart';
import '../../features/control/domain/control_orders.dart';
import '../../features/control/domain/control_summary.dart';
import '../../features/control/domain/payouts.dart';
import '../../features/control/domain/review.dart';
import '../../features/management/domain/authorizations.dart';
import '../../features/team/domain/bonus.dart';
import '../../features/team/domain/my_week.dart';
import '../../features/warehouse/domain/warehouse.dart';
import '../money/money.dart';
import '../network/api_exception.dart';
import '../network/paged_result.dart';
import 'demo_audit.dart';
import 'demo_backend.dart';
import 'demo_sales.dart';
import 'demo_team.dart';
import 'demo_warehouse.dart';

const _jime = 'Jime';
const _management = 'Dirección';

const _weekdays = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

/// `sábado 5 dic` (la demo es de diciembre).
String _day(DateTime date) => '${_weekdays[date.weekday - 1]} ${date.day} dic';

/// «Ailén y Alison», «Kim, Alison e Isaí».
String _joined(List<String> names) {
  if (names.length < 2) return names.join();
  final last = names.last;
  final and = RegExp(r'^(i|hi(?![aeiouáéíóú]))', caseSensitive: false).hasMatch(last) ? 'e' : 'y';
  return '${names.sublist(0, names.length - 1).join(', ')} $and $last';
}

class DemoControl {
  DemoControl({
    required this._now,
    required this._sales,
    required this._team,
    required this._warehouse,
    required this._audit,
  });

  static const weekNumber = 1;

  final DateTime Function() _now;
  final DemoSales _sales;
  final DemoTeam _team;
  final DemoWarehouse _warehouse;
  final DemoAudit _audit;

  /// Los PIN que Jime cambió (id de integrante → PIN).
  final Map<String, String> pins = {};

  // ─────────────────────────────────────────────────────────────── resumen

  ControlSummary summary() {
    final week = DemoBackend.week;
    final rows = _bonusRows();
    final items = pending();
    int count(PendingType type) => items.where((i) => i.type == type).length;
    final level = BonusRules.levelFor(DemoBackend.collected, week.target);
    final prize = BonusRules.prizeAt(week.basePrize, level);
    Money total(Compliance c) => rows
        .where((r) => r.compliance == c)
        .fold(Money.zero, (sum, r) => sum + r.shareAmount);

    return ControlSummary(
      asOf: DemoBackend.asOf,
      week: week,
      collected: DemoBackend.collected,
      pending: PendingReview(
        payments: count(PendingType.payment),
        evidence: count(PendingType.evidence),
        cashClosings: count(PendingType.cashClosing),
        deliverables: count(PendingType.deliverable),
      ),
      members: [
        for (final member in DemoTeam.teamMembers) _memberResult(member),
      ],
      bonus: BonusResult(
        level: level,
        prize: prize,
        payable: total(Compliance.passes),
        unpaidFailing: total(Compliance.fails),
        unpaidPending: total(Compliance.pending),
      ),
    );
  }

  MemberResult _memberResult(Member member) {
    final kpi = _team.kpiOf(member.id);
    final deliverables = kpi.deliverables;
    final String? note;
    if (kpi.closedReason != null) {
      note = 'Cerrado por Jime: ${kpi.closedReason}';
    } else if (deliverables != null && !deliverables.complete) {
      note = '${deliverables.approved} de ${deliverables.total} entregas validadas';
    } else {
      note = null;
    }
    return MemberResult(
      id: member.id,
      name: member.name,
      scorePercent: kpi.scorePercent,
      minimumPercent: kpi.minimumPercent,
      compliance: kpi.compliance,
      fundShareRate: _team.shareRate(member.id),
      note: note,
    );
  }

  // ─────────────────────────────────────────────────────────────── bandeja

  /// Lo más antiguo primero.
  List<PendingItem> pending({PendingType? type}) {
    final items = [
      for (final p in _sales.proofsToReview())
        PendingItem(
          type: PendingType.payment,
          id: p.id,
          title: '${p.customerName} · ${p.sellerName ?? 'Tienda web'}',
          subtitle: p.method.label,
          createdAt: p.submittedAt!,
          amount: p.amount,
        ),
      ..._team.pendingEvidence(),
      for (final day in _warehouse.sentClosings())
        PendingItem(
          type: PendingType.cashClosing,
          id: day.closingId!,
          title: '${day.closedByName} · cierre del ${_day(day.businessDate)}',
          subtitle: 'QR, transferencia y efectivo',
          createdAt: day.sentAt!,
          amount: day.collected,
        ),
      ..._team.pendingDeliverables(),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return type == null ? items : items.where((i) => i.type == type).toList();
  }

  // ───────────────────────────────────────────────────────── validaciones

  PaymentReview paymentReview(String id) => _sales.paymentReview(id);

  PaymentReview confirmPayment(
    String id, {
    required bool amountMatches,
    required bool destinationOk,
  }) {
    final review = _sales.confirmPayment(
      id,
      amountMatches: amountMatches,
      destinationOk: destinationOk,
    );
    _audit.log(_jime, 'Confirmó el pago ${review.orderNumber} (${review.amount.format()})');
    return review;
  }

  PaymentReview rejectPayment(String id, String reason) {
    final review = _sales.rejectPayment(id, reason);
    _audit.log(_jime, 'Rechazó el comprobante de ${review.orderNumber}: ${reason.trim()}');
    return review;
  }

  EvidenceReview evidenceReview(String resultId) => _team.evidenceReview(resultId);

  EvidenceReview validateResult(String resultId, double actual) {
    final before = _team.evidenceReview(resultId).indicator.actual;
    final review = _team.validateResult(resultId, actual);
    String number(double? v) =>
        v == null ? 'sin cargar' : (v == v.roundToDouble() ? '${v.round()}' : '$v');
    _audit.log(
      _jime,
      'Cargó el valor real de «${review.indicator.name}» de ${review.memberName}: '
      '${number(before)} → ${number(actual)}',
    );
    return review;
  }

  EvidenceReview observeResult(String resultId, String note) {
    final review = _team.observeResult(resultId, note);
    _audit.log(
      _jime,
      'Observó la evidencia de «${review.indicator.name}» de ${review.memberName}: ${note.trim()}',
    );
    return review;
  }

  CashDay validateCashClosing(String id) {
    final day = _warehouse.validateClosing(id);
    _audit.log(_jime, 'Validó el cierre de caja del ${_day(day.businessDate)}');
    return day;
  }

  CashDay observeCashClosing(String id, String note) {
    final day = _warehouse.observeClosing(id, note);
    _audit.log(
      _jime,
      'Pidió corregir la caja del ${_day(day.businessDate)}: ${note.trim()}',
    );
    return day;
  }

  Deliverable validateDeliverable(String id, DateTime deliveredOn) {
    final d = _team.validateDeliverable(id, deliveredOn);
    _audit.log(
      _jime,
      'Validó la entrega «${d.title}» de ${d.memberName} (${d.status.label.toLowerCase()})',
    );
    return d;
  }

  Deliverable rejectDeliverable(String id, String note) {
    final d = _team.rejectDeliverable(id, note);
    _audit.log(_jime, 'No validó «${d.title}» de ${d.memberName}: ${note.trim()}');
    return d;
  }

  // ───────────────────────────────────────────────────── pedidos de todos

  PagedResult<ControlOrderSummary> orders({String? search, int page = 1}) =>
      _sales.allOrders(search: search, page: page);

  ControlOrder order(String id) => _sales.controlOrder(id);

  void returnOrder(String id, String reason) {
    _sales.returnOrder(id, reason);
    _audit.log(_jime, 'Registró la devolución de N-$id: ${reason.trim()}');
  }

  void markDuplicate(String id, String originalId) {
    final number = _sales.markDuplicate(id, originalId);
    _audit.log(_jime, 'Quitó $number por duplicado de N-$originalId');
  }

  // ─────────────────────────────────────────────── cierre semanal y bono

  /// La demo solo tiene la primera semana.
  ComplianceWeek compliance({int? weekNumber}) {
    _requireWeek(weekNumber ?? DemoControl.weekNumber);
    return ComplianceWeek(
      weekNumber: DemoControl.weekNumber,
      week: DemoBackend.week,
      currentWeek: DemoControl.weekNumber,
      rows: _team.compliance(),
    );
  }

  WeekClosingStatus _status = WeekClosingStatus.open;
  String? _observations;
  String? _returnReason;
  DateTime? _sentAt;
  DateTime? _authorizedAt;

  /// La foto del reparto al enviar a Dirección.
  List<BonusRow>? _snapshot;
  final Map<String, DateTime> _paid = {};

  bool get _isEditable =>
      _status == WeekClosingStatus.open || _status == WeekClosingStatus.returned;

  ({ClosingCheck payments, ClosingCheck evidence}) _systemChecks() {
    final week = DemoBackend.week;
    final p = _sales.paymentsBetween(week.startsOn, week.endsOn);
    final missing = [
      if (p.proofs > 0) '${p.proofs} ${p.proofs == 1 ? 'comprobante' : 'comprobantes'} por revisar',
      if (p.cash > 0)
        '${p.cash} en efectivo sin caja validada',
    ];
    final waiting = [
      for (final m in DemoTeam.teamMembers)
        if (_team.pendingEvidence().any((i) => i.title.startsWith('${m.name} · '))) m.name,
    ];
    final members = DemoTeam.teamMembers.length;
    return (
      payments: ClosingCheck(
        ok: missing.isEmpty,
        detail: missing.isEmpty
            ? '${p.confirmed} de ${p.confirmed} pagos confirmados'
            : 'Faltan ${_joined(missing)}',
      ),
      evidence: ClosingCheck(
        ok: waiting.isEmpty,
        detail: waiting.isEmpty
            ? '$members de $members personas sin evidencia por revisar'
            : 'Falta revisar la evidencia de ${_joined(waiting)}',
      ),
    );
  }

  List<PendingMember> _pendingMembers() => [
        for (final row in _team.compliance())
          if (row.compliance == Compliance.pending)
            PendingMember(
              id: row.id,
              name: row.name,
              pendingReason: row.deliverablesTotal != null &&
                      row.deliverablesOnTime! < row.deliverablesTotal!
                  ? '${row.deliverablesOnTime} de ${row.deliverablesTotal} entregas validadas'
                  : 'Faltan ${row.indicatorsTotal - row.indicatorsLoaded} valores reales',
            ),
      ];

  WeeklyClosing weeklyClosing({int? weekNumber}) {
    _requireWeek(weekNumber ?? DemoControl.weekNumber);
    final checks = _systemChecks();
    final week = DemoBackend.week;
    final removed = _sales.duplicatesBetween(week.startsOn, week.endsOn);
    final authorized = _status == WeekClosingStatus.authorized ||
        _status == WeekClosingStatus.paid;
    return WeeklyClosing(
      weekNumber: DemoControl.weekNumber,
      currentWeek: DemoControl.weekNumber,
      // La demo está fija en el domingo 6: deja enviar ese mismo día.
      sendableFrom: week.endsOn,
      week: week,
      status: _status,
      paymentsReconciled: checks.payments,
      kpiEvidence: checks.evidence,
      duplicates: ClosingCheck(
        ok: !_isEditable,
        detail: removed.isEmpty
            ? 'Ningún duplicado quitado esta semana'
            : '${removed.length} ${removed.length == 1 ? 'duplicado quitado' : 'duplicados quitados'} '
                '(${removed.join(', ')})',
      ),
      direction: ClosingCheck(
        ok: authorized,
        detail: authorized ? 'Autorizado el ${_authorizedAt!.day} dic' : 'Falta su aprobación',
      ),
      pendingMembers: _isEditable ? _pendingMembers() : const [],
      observations: _observations,
      returnReason: _status == WeekClosingStatus.returned ? _returnReason : null,
    );
  }

  WeeklyClosing sendWeeklyClosing(
    int number, {
    required bool duplicatesCleared,
    Map<String, String> closePending = const {},
    String? observations,
  }) {
    _requireWeek(number);
    if (!_isEditable) {
      throw const ConflictException(
        code: 'closing_already_sent',
        message: 'El cierre de la semana ya se envió.',
      );
    }
    final checks = _systemChecks();
    if (!checks.payments.ok || !checks.evidence.ok || !duplicatesCleared) {
      throw ValidationException(
        code: 'checks_failed',
        message: !checks.payments.ok
            ? checks.payments.detail
            : (!checks.evidence.ok ? checks.evidence.detail : 'Confirma que no quedan duplicados.'),
      );
    }
    final waiting = _pendingMembers();
    for (final MapEntry(key: id, value: reason) in closePending.entries) {
      if (!waiting.any((m) => m.id == id)) {
        throw const ValidationException(
          code: 'not_pending',
          message: 'Solo se cierra a mano a quien está pendiente.',
        );
      }
      if (reason.trim().isEmpty) {
        throw const ValidationException(message: 'Escribe el motivo de cada cierre.');
      }
    }
    final unresolved = [
      for (final m in waiting)
        if (!closePending.containsKey(m.id)) m.name,
    ];
    if (unresolved.isNotEmpty) {
      throw ConflictException(
        code: 'pending_members',
        message: '${_joined(unresolved)} '
            '${unresolved.length == 1 ? 'sigue pendiente' : 'siguen pendientes'}.',
      );
    }

    _team.closedReasons = {
      for (final MapEntry(key: id, value: reason) in closePending.entries) id: reason.trim(),
    };
    _snapshot = _previewRows();
    _status = WeekClosingStatus.sent;
    _team.weekWithDirection = true;
    _sentAt = _now();
    _returnReason = null;
    final note = observations?.trim() ?? '';
    _observations = note.isEmpty ? null : note;
    for (final m in waiting.where((m) => closePending.containsKey(m.id))) {
      _audit.log(_jime, 'Cerró a ${m.name} como «no cumple»: ${closePending[m.id]!.trim()}');
    }
    _audit.log(_jime, 'Envió el cierre de la semana ${DemoBackend.week.label} a Dirección');
    return weeklyClosing();
  }

  List<BonusRow> _previewRows() {
    final week = DemoBackend.week;
    final fund = BonusRules.prizeAt(
      week.basePrize,
      BonusRules.levelFor(DemoBackend.collected, week.target),
    );
    return [
      for (final member in DemoTeam.teamMembers) _bonusRow(member, fund),
    ];
  }

  BonusRow _bonusRow(Member member, Money fund) {
    final kpi = _team.kpiOf(member.id);
    final share = _team.shareRate(member.id);
    final value = fund.percent(share);
    return BonusRow(
      id: member.id,
      name: member.name,
      shareRate: share,
      compliance: kpi.compliance,
      shareAmount: value,
      amount: switch (kpi.compliance) {
        Compliance.passes => value,
        Compliance.fails => Money.zero,
        Compliance.pending => null,
      },
      closedReason: kpi.closedReason,
    );
  }

  /// La foto enviada, o la vista previa mientras está abierto o devuelto.
  List<BonusRow> _bonusRows() => [
        for (final row in _isEditable ? _previewRows() : _snapshot!)
          BonusRow(
            id: row.id,
            name: row.name,
            shareRate: row.shareRate,
            compliance: row.compliance,
            shareAmount: row.shareAmount,
            amount: row.amount,
            paidAt: _paid[row.id],
            closedReason: row.closedReason,
          ),
      ];

  WeekBonus bonus({int? weekNumber}) {
    _requireWeek(weekNumber ?? DemoControl.weekNumber);
    final week = DemoBackend.week;
    final level = BonusRules.levelFor(DemoBackend.collected, week.target);
    final fund = BonusRules.prizeAt(week.basePrize, level);
    final rows = _bonusRows();
    final payable = rows.fold(
      Money.zero,
      (sum, r) => r.compliance == Compliance.passes ? sum + r.shareAmount : sum,
    );
    return WeekBonus(
      weekNumber: DemoControl.weekNumber,
      currentWeek: DemoControl.weekNumber,
      week: week,
      status: _status,
      collected: DemoBackend.collected,
      achievementPercent: BonusRules.percent(DemoBackend.collected, week.target),
      level: level,
      releaseFactor: level.factor.toDouble(),
      fund: fund,
      payable: payable,
      unpaid: fund - payable,
      members: rows,
    );
  }

  WeekBonus markBonusPaid(int number, String memberId) {
    _requireWeek(number);
    if (_status != WeekClosingStatus.authorized && _status != WeekClosingStatus.paid) {
      throw const ConflictException(
        code: 'not_ready_to_pay',
        message: 'Todavía no lo autorizó Dirección.',
      );
    }
    final row = _snapshot!.where((r) => r.id == memberId).firstOrNull;
    if (row == null || row.compliance != Compliance.passes || _paid.containsKey(memberId)) {
      throw const ConflictException(
        code: 'not_ready_to_pay',
        message: 'Ese pago no está pendiente.',
      );
    }
    _paid[memberId] = _now();
    _audit.log(_jime, 'Marcó pagado el bono de ${row.name} (${row.shareAmount.format()})');
    final passing = _snapshot!.where((r) => r.compliance == Compliance.passes);
    if (passing.every((r) => _paid.containsKey(r.id))) _status = WeekClosingStatus.paid;
    return bonus();
  }

  static void _requireWeek(int number) {
    if (number != weekNumber) {
      throw const NotFoundException('En la demo solo está la primera semana.');
    }
  }

  // ─────────────────────────────────────────────────────────── comisiones

  MonthCommissions commissions(String month) {
    final start = _monthStart(month);
    final rows = <CommissionRow>[];
    var ratesPending = false;
    var total = Money.zero;
    for (final member in DemoTeam.teamMembers.where((m) => m.role.canSell)) {
      final c = _sales.commissionsOf(member.id, start);
      ratesPending = ratesPending || c.ratesPending;
      final amount = c.ratesPending ? null : c.rated + c.adjustments;
      if (amount != null) total = total + amount;
      rows.add(CommissionRow(
        id: member.id,
        name: member.name,
        paidSales: c.paidSales,
        adjustments: c.adjustments,
        amount: amount,
      ));
    }
    return MonthCommissions(
      month: month,
      status: SettlementStatus.open,
      ratesPending: ratesPending,
      total: ratesPending ? null : total,
      members: rows,
      settlesOn: DateTime(start.year, start.month + 1, 0),
    );
  }

  /// La liquidación se envía cuando el mes termina.
  MonthCommissions sendCommissions(String month) {
    final start = _monthStart(month);
    final nextMonth = DateTime(start.year, start.month + 1);
    if (_now().isBefore(nextMonth)) {
      throw const ConflictException(
        code: 'month_not_ended',
        message: 'La liquidación se envía cuando termina el mes.',
      );
    }
    throw const ConflictException(
      code: 'nothing_to_settle',
      message: 'No hay comisiones cobradas en ese mes.',
    );
  }

  MonthCommissions markCommissionsPaid(String month) => throw const ConflictException(
        code: 'not_ready_to_pay',
        message: 'Todavía no lo autorizó Dirección.',
      );

  static DateTime _monthStart(String month) {
    final parts = month.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1]);
  }

  // ───────────────────────────────────────────────────────────── precios

  late final List<_PriceRequest> _requests = [
    _PriceRequest(
      id: 'pc-1',
      productId: 'p-8924',
      proposed: PriceValues(
        priceUnit: Money.parse('89'),
        priceWholesale: Money.parse('84'),
      ),
      requestedAt: DateTime(2026, 12, 6, 11),
    ),
  ];

  _PriceRequest? _pendingRequest(String productId) =>
      _requests.where((r) => r.productId == productId && r.pending).firstOrNull;

  PriceSheet priceSheet(String productId) {
    final product = _sales.item(productId);
    final request = _pendingRequest(productId);
    return PriceSheet(
      productId: productId,
      itemCode: product.itemCode,
      name: product.name,
      category: product.category,
      current: _sales.currentPrice(productId),
      pendingChange: request == null
          ? null
          : PriceChange(
              id: request.id,
              proposed: request.proposed,
              requestedBy: _jime,
              requestedAt: request.requestedAt,
              reason: request.reason,
            ),
    );
  }

  PriceSheet proposePrice(String productId, PriceValues proposed, {String? reason}) {
    final product = _sales.item(productId);
    if (_pendingRequest(productId) != null) {
      throw const ConflictException(
        code: 'change_pending',
        message: 'Ese producto ya tiene un cambio esperando a Dirección.',
      );
    }
    final p = proposed;
    if (p.priceUnit == null &&
        p.priceWholesale == null &&
        p.wholesaleMinQty == null &&
        p.commissionPct == null &&
        p.cost == null) {
      throw const ValidationException(message: 'No hay cambios.');
    }
    final unit = p.priceUnit ?? product.priceUnit;
    final wholesale = p.priceWholesale ?? product.priceWholesale!;
    final minimum = p.wholesaleMinQty ?? product.wholesaleMinQty!;
    final rate = p.commissionPct;
    if (unit <= Money.zero || wholesale <= Money.zero || minimum < 2 || wholesale > unit) {
      throw const ValidationException(message: 'Revisa los precios y el mínimo.');
    }
    if (rate != null && (rate < 0 || rate > 100)) {
      throw const ValidationException(message: 'La comisión va de 0 a 100 %.');
    }
    final note = reason?.trim() ?? '';
    _requests.add(_PriceRequest(
      id: 'pc-${_requests.length + 1}',
      productId: productId,
      proposed: proposed,
      requestedAt: _now(),
      reason: note.isEmpty ? null : note,
    ));
    _audit.log(_jime, 'Propuso un cambio de precio para ${product.name}');
    return priceSheet(productId);
  }

  // ──────────────────────────────────────────────────────── Dirección

  List<AuthorizationItem> authorizations() => [
        if (_status == WeekClosingStatus.sent) _bonusAuthorization(),
        for (final request in _requests.where((r) => r.pending)) _priceAuthorization(request),
      ]..sort((a, b) => a.requestedAt.compareTo(b.requestedAt));

  AuthorizationItem _bonusAuthorization() => AuthorizationItem(
        type: AuthorizationType.weeklyBonus,
        id: '$weekNumber',
        title: 'Bono semana ${DemoBackend.week.label}',
        requestedBy: _jime,
        requestedAt: _sentAt!,
        amount: bonus().payable,
      );

  AuthorizationItem _priceAuthorization(_PriceRequest request) => AuthorizationItem(
        type: AuthorizationType.priceChange,
        id: request.id,
        title: 'Precio de ${_sales.item(request.productId).name}',
        requestedBy: _jime,
        requestedAt: request.requestedAt,
      );

  AuthorizationDetail authorization(AuthorizationType type, String id) {
    switch (type) {
      case AuthorizationType.weeklyBonus when _status == WeekClosingStatus.sent:
        final rows = _bonusRows();
        final checks = _systemChecks();
        return AuthorizationDetail(
          item: _bonusAuthorization(),
          pays: [
            for (final r in rows)
              if (r.compliance == Compliance.passes)
                PayLine(name: r.name, amount: r.shareAmount),
          ],
          unpaid: [
            for (final r in rows)
              if (r.compliance != Compliance.passes)
                PayLine(name: r.name, amount: r.shareAmount, reason: _unpaidReason(r)),
          ],
          checks: [
            'Cobros conciliados: ${checks.payments.detail}',
            'KPI con evidencia revisada',
            'Duplicados depurados',
            if (_observations != null) 'Observaciones de Jime: $_observations',
          ],
          changes: const [],
          canApprove: true,
        );
      case AuthorizationType.priceChange:
        final request = _pendingById(id);
        final current = _sales.currentPrice(request.productId);
        final p = request.proposed;
        String money(Money? m) => m?.format() ?? 'Sin definir';
        String percent(double? v) => v == null ? 'Por definir' : '${_number(v)} %';
        return AuthorizationDetail(
          item: _priceAuthorization(request),
          pays: const [],
          unpaid: const [],
          checks: [
            if (p.commissionPct != null)
              'Las ventas sin % de este producto que no se liquidaron toman esta comisión.',
            'Las ventas ya registradas conservan su precio.',
            if (request.reason != null) 'Motivo de Jime: ${request.reason}',
          ],
          changes: [
            if (p.priceUnit != null)
              ValueChange(
                  label: 'Minorista', before: money(current.priceUnit), after: money(p.priceUnit)),
            if (p.priceWholesale != null)
              ValueChange(
                  label: 'Mayorista',
                  before: money(current.priceWholesale),
                  after: money(p.priceWholesale)),
            if (p.wholesaleMinQty != null)
              ValueChange(
                  label: 'Mínimo mayorista',
                  before: '${current.wholesaleMinQty} u.',
                  after: '${p.wholesaleMinQty} u.'),
            if (p.commissionPct != null)
              ValueChange(
                  label: 'Comisión',
                  before: percent(current.commissionPct),
                  after: percent(p.commissionPct)),
            if (p.cost != null)
              ValueChange(label: 'Costo', before: money(current.cost), after: money(p.cost)),
          ],
          canApprove: true,
        );
      default:
        throw const NotFoundException('Eso ya no espera autorización.');
    }
  }

  static String _number(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';

  String _unpaidReason(BonusRow row) {
    if (row.closedReason != null) return 'Cerrado por Jime: ${row.closedReason}';
    final kpi = _team.kpiOf(row.id);
    final deliverables = kpi.deliverables;
    if (deliverables != null && !deliverables.complete) {
      return '${deliverables.approved} de ${deliverables.total} entregas a tiempo';
    }
    return 'KPI ${kpi.scorePercent} % de ${kpi.minimumPercent} %';
  }

  _PriceRequest _pendingById(String id) {
    final request = _requests.where((r) => r.id == id && r.pending).firstOrNull;
    if (request == null) throw const NotFoundException('Eso ya no espera autorización.');
    return request;
  }

  void approve(AuthorizationType type, String id) {
    switch (type) {
      case AuthorizationType.weeklyBonus when _status == WeekClosingStatus.sent:
        final payable = bonus().payable;
        _status = WeekClosingStatus.authorized;
        _authorizedAt = _now();
        _team
          ..weekAuthorized = true
          ..weekWithDirection = false;
        _audit.log(
          _management,
          'Autorizó el bono de la semana ${DemoBackend.week.label} (${payable.format()})',
        );
      case AuthorizationType.priceChange:
        final request = _pendingById(id);
        final before = _sales.item(request.productId);
        final filled = _sales.applyPriceChange(request.productId, request.proposed);
        request.pending = false;
        final after = _sales.item(request.productId);
        final price = before.priceUnit == after.priceUnit
            ? ''
            : ': ${before.priceUnit.formatInline()} → ${after.priceUnit.formatInline()}';
        final retro = filled == 0
            ? ''
            : ' · $filled ${filled == 1 ? 'venta sin % lo tomó' : 'ventas sin % lo tomaron'}';
        _audit.log(_management, 'Autorizó el precio de ${before.name}$price$retro');
      default:
        throw const NotFoundException('Eso ya no espera autorización.');
    }
  }

  void sendBack(AuthorizationType type, String id, String reason) {
    if (reason.trim().isEmpty) {
      throw const ValidationException(message: 'Escribe el motivo.');
    }
    switch (type) {
      case AuthorizationType.weeklyBonus when _status == WeekClosingStatus.sent:
        _status = WeekClosingStatus.returned;
        _returnReason = reason.trim();
        // Los cierres a mano se vuelven a indicar al reenviar.
        _team
          ..closedReasons = {}
          ..weekWithDirection = false;
        _snapshot = null;
        _audit.log(_management, 'Devolvió el cierre a Jime: ${reason.trim()}');
      case AuthorizationType.priceChange:
        final request = _pendingById(id);
        request.pending = false;
        _audit.log(
          _management,
          'No aprobó el precio de ${_sales.item(request.productId).name}: ${reason.trim()}',
        );
      default:
        throw const NotFoundException('Eso ya no espera autorización.');
    }
  }

  // ───────────────────────────────────────────── historial y accesos

  PagedResult<AuditEntry> auditPage(int page) => _audit.page(page);

  SystemStatus systemStatus() => SystemStatus(
        lastBackupAt: DateTime(2026, 12, 6, 3),
        restoreTestedAt: DateTime(2026, 11, 29, 16),
      );

  /// Las cuentas del equipo: las de Jime y Dirección no se cambian desde aquí.
  List<TeamAccount> accounts() => [
        for (final m in DemoTeam.teamMembers)
          TeamAccount(id: m.id, code: m.code, name: m.name, title: m.title),
      ];

  void resetPin(String memberId, String newPin) {
    final member = _teamMember(memberId);
    if (!RegExp(r'^\d{4}$').hasMatch(newPin)) {
      throw const ValidationException(message: 'El PIN tiene 4 números.');
    }
    pins[memberId] = newPin;
    // El PIN nunca se guarda en el historial.
    _audit.log(_jime, 'Puso un PIN nuevo a ${member.name}');
  }

  void revokeSessions(String memberId) {
    final member = _teamMember(memberId);
    _audit.log(_jime, 'Cerró las sesiones de ${member.name}');
  }

  static Member _teamMember(String id) {
    final member = DemoTeam.teamMembers.where((m) => m.id == id).firstOrNull;
    if (member == null) {
      throw const NotFoundException('Solo se cambian las cuentas del equipo.');
    }
    return member;
  }
}

class _PriceRequest {
  _PriceRequest({
    required this.id,
    required this.productId,
    required this.proposed,
    required this.requestedAt,
    this.reason,
  });

  final String id;
  final String productId;
  final PriceValues proposed;
  final DateTime requestedAt;
  final String? reason;
  bool pending = true;
}
