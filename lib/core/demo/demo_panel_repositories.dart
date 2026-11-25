/// Repositorios de prueba del panel de Jime y de Dirección. Aplican quién
/// puede hacer qué y delegan en la demo.
library;

import '../../features/control/domain/admin.dart';
import '../../features/control/domain/control_orders.dart';
import '../../features/control/domain/payouts.dart';
import '../../features/control/domain/review.dart';
import '../../features/management/domain/authorizations.dart';
import '../../features/team/domain/my_week.dart';
import '../../features/warehouse/domain/warehouse.dart';
import '../network/api_exception.dart';
import '../network/paged_result.dart';
import 'demo_backend.dart';

abstract class _Panel {
  const _Panel(this.backend, this.latency);

  final DemoBackend backend;
  final Duration latency;

  /// Solo Jime.
  Future<T> control<T>(T Function() action) => _run(backend.requireControl, action);

  /// Jime y Dirección (lectura).
  Future<T> either<T>(T Function() action) => _run(backend.requireControlSide, action);

  /// Solo Dirección.
  Future<T> management<T>(T Function() action) => _run(backend.requireManagement, action);

  Future<T> _run<T>(void Function() permission, T Function() action) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    permission();
    return action();
  }
}

class DemoReviewRepository extends _Panel implements ReviewRepository {
  const DemoReviewRepository(super.backend, super.latency);

  @override
  Future<List<PendingItem>> pending({PendingType? type}) =>
      control(() => backend.control.pending(type: type));

  @override
  Future<PaymentReview> payment(String id) =>
      control(() => backend.control.paymentReview(id));

  @override
  Future<PaymentReview> confirmPayment(
    String id, {
    required bool amountMatches,
    required bool destinationOk,
    DateTime? receivedAt,
  }) =>
      control(() => backend.control
          .confirmPayment(id, amountMatches: amountMatches, destinationOk: destinationOk));

  @override
  Future<PaymentReview> rejectPayment(String id, {required String reason}) =>
      control(() => backend.control.rejectPayment(id, reason));

  @override
  Future<EvidenceReview> evidence(String resultId) =>
      control(() => backend.control.evidenceReview(resultId));

  @override
  Future<EvidenceReview> validateResult(String resultId,
          {required double actual, String? note}) =>
      control(() => backend.control.validateResult(resultId, actual));

  @override
  Future<EvidenceReview> observeResult(String resultId, {required String note}) =>
      control(() => backend.control.observeResult(resultId, note));

  @override
  Future<CashDay> cashClosing(String id) =>
      control(() => backend.warehouse.closingById(id));

  @override
  Future<CashDay> validateCashClosing(String id) =>
      control(() => backend.control.validateCashClosing(id));

  @override
  Future<CashDay> observeCashClosing(String id, {required String note}) =>
      control(() => backend.control.observeCashClosing(id, note));

  @override
  Future<List<Deliverable>> deliverables() =>
      control(() => backend.team.allDeliverables());

  @override
  Future<Deliverable> validateDeliverable(String id, {required DateTime deliveredOn}) =>
      control(() => backend.control.validateDeliverable(id, deliveredOn));

  @override
  Future<Deliverable> rejectDeliverable(String id, {required String note}) =>
      control(() => backend.control.rejectDeliverable(id, note));

  @override
  Future<void> returnOrder(String orderId, {required String reason}) =>
      control(() => backend.control.returnOrder(orderId, reason));

  @override
  Future<void> markDuplicate(String orderId, {required String originalOrderId}) =>
      control(() => backend.control.markDuplicate(orderId, originalOrderId));

  @override
  Future<PagedResult<ControlOrderSummary>> orders({String? search, int page = 1}) =>
      control(() => backend.control.orders(search: search, page: page));

  @override
  Future<ControlOrder> order(String id) => control(() => backend.control.order(id));

  @override
  Future<MyWeek> memberWeek(String memberId, {int? weekNumber}) =>
      control(() => backend.team.weekOf(memberId));
}

class DemoPayoutsRepository extends _Panel implements PayoutsRepository {
  const DemoPayoutsRepository(super.backend, super.latency);

  @override
  Future<List<ComplianceRow>> compliance({int? weekNumber}) =>
      either(() => backend.team.compliance());

  @override
  Future<WeeklyClosing> weeklyClosing({int? weekNumber}) =>
      control(() => backend.control.weeklyClosing());

  @override
  Future<WeeklyClosing> sendWeeklyClosing(
    int weekNumber, {
    required bool duplicatesCleared,
    Map<String, String> closePending = const {},
    String? observations,
  }) =>
      control(() => backend.control.sendWeeklyClosing(
            weekNumber,
            duplicatesCleared: duplicatesCleared,
            closePending: closePending,
            observations: observations,
          ));

  @override
  Future<WeekBonus> bonus({int? weekNumber}) => either(() => backend.control.bonus());

  @override
  Future<WeekBonus> markBonusPaid(int weekNumber, String memberId) =>
      control(() => backend.control.markBonusPaid(weekNumber, memberId));

  @override
  Future<MonthCommissions> commissions(String month) =>
      either(() => backend.control.commissions(month));

  @override
  Future<MonthCommissions> sendCommissions(String month) =>
      control(() => backend.control.sendCommissions(month));

  @override
  Future<MonthCommissions> markCommissionsPaid(String month) =>
      control(() => backend.control.markCommissionsPaid(month));
}

class DemoAdminRepository extends _Panel implements AdminRepository {
  const DemoAdminRepository(super.backend, super.latency);

  @override
  Future<PriceSheet> priceSheet(String productId) =>
      either(() => backend.control.priceSheet(productId));

  @override
  Future<PriceSheet> proposePrice(String productId, PriceValues proposed, {String? reason}) =>
      control(() => backend.control.proposePrice(productId, proposed, reason: reason));

  @override
  Future<PagedResult<AuditEntry>> audit({int page = 1}) =>
      either(() => backend.control.auditPage(page));

  @override
  Future<List<int>> downloadReport(ReportType type, {required String period}) => either(
        () => throw const ValidationException(
          message: 'En la demo no se genera el Excel: lo arma el backend.',
        ),
      );

  @override
  Future<SystemStatus> systemStatus() => control(() => backend.control.systemStatus());

  @override
  Future<List<TeamAccount>> members() => control(() => backend.control.accounts());

  @override
  Future<void> resetPin(String memberId, String newPin) =>
      control(() => backend.control.resetPin(memberId, newPin));

  @override
  Future<void> revokeSessions(String memberId) =>
      control(() => backend.control.revokeSessions(memberId));
}

class DemoManagementRepository extends _Panel implements ManagementRepository {
  const DemoManagementRepository(super.backend, super.latency);

  @override
  Future<List<AuthorizationItem>> pending() =>
      management(() => backend.control.authorizations());

  @override
  Future<AuthorizationDetail> detail(AuthorizationType type, String id) =>
      management(() => backend.control.authorization(type, id));

  @override
  Future<void> approve(AuthorizationType type, String id) =>
      management(() => backend.control.approve(type, id));

  @override
  Future<void> sendBack(AuthorizationType type, String id, {required String reason}) =>
      management(() => backend.control.sendBack(type, id, reason));
}
