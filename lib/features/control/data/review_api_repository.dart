import '../../../core/network/api_client.dart';
import '../../../core/network/api_paths.dart';
import '../../team/data/team_api_repository.dart' show apiDate;
import '../../team/domain/my_week.dart';
import '../../warehouse/domain/warehouse.dart';
import '../domain/review.dart';

class ReviewApiRepository implements ReviewRepository {
  ReviewApiRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<PendingItem>> pending({PendingType? type}) async {
    final json = await _api.get(
      ApiPaths.controlPending,
      query: {'type': ?type?.apiValue},
    );
    return json.list('data').map(PendingItem.fromJson).toList();
  }

  @override
  Future<PaymentReview> payment(String id) async =>
      _payment(await _api.get(ApiPaths.controlPayment(id)));

  @override
  Future<PaymentReview> confirmPayment(
    String id, {
    required bool amountMatches,
    required bool destinationOk,
    DateTime? receivedAt,
  }) async =>
      _payment(await _api.post(ApiPaths.controlPaymentConfirm(id), body: {
        'amount_matches': amountMatches,
        'destination_ok': destinationOk,
        'received_at': receivedAt?.toUtc().toIso8601String(),
      }));

  @override
  Future<PaymentReview> rejectPayment(String id, {required String reason}) async =>
      _payment(await _api.post(ApiPaths.controlPaymentReject(id), body: {'reason': reason}));

  @override
  Future<EvidenceReview> evidence(String resultId) async =>
      _evidence(await _api.get(ApiPaths.controlKpiResult(resultId)));

  @override
  Future<EvidenceReview> validateResult(
    String resultId, {
    required double actual,
    String? note,
  }) async =>
      _evidence(await _api.post(
        ApiPaths.controlKpiValidate(resultId),
        body: {'actual': actual, 'note': note},
      ));

  @override
  Future<EvidenceReview> observeResult(String resultId, {required String note}) async =>
      _evidence(await _api.post(ApiPaths.controlKpiObserve(resultId), body: {'note': note}));

  @override
  Future<CashDay> cashClosing(String id) async =>
      _cash(await _api.get(ApiPaths.controlCashClosing(id)));

  @override
  Future<CashDay> validateCashClosing(String id) async =>
      _cash(await _api.post(ApiPaths.controlCashValidate(id)));

  @override
  Future<CashDay> observeCashClosing(String id, {required String note}) async =>
      _cash(await _api.post(ApiPaths.controlCashObserve(id), body: {'note': note}));

  @override
  Future<List<Deliverable>> deliverables() async {
    final json = await _api.get(ApiPaths.controlDeliverables);
    return json.list('data').map(Deliverable.fromJson).toList();
  }

  @override
  Future<Deliverable> validateDeliverable(String id, {required DateTime deliveredOn}) async =>
      _deliverable(await _api.post(
        ApiPaths.controlDeliverableValidate(id),
        body: {'delivered_on': apiDate(deliveredOn)},
      ));

  @override
  Future<Deliverable> rejectDeliverable(String id, {required String note}) async =>
      _deliverable(
        await _api.post(ApiPaths.controlDeliverableReject(id), body: {'note': note}),
      );

  @override
  Future<void> returnOrder(String orderId, {required String reason}) => _api
      .postNoContent(ApiPaths.controlOrderReturn(orderId), body: {'reason': reason});

  @override
  Future<void> markDuplicate(String orderId, {required String originalOrderId}) =>
      _api.postNoContent(
        ApiPaths.controlOrderDuplicate(orderId),
        body: {'original_order_id': originalOrderId},
      );

  PaymentReview _payment(Json json) => PaymentReview.fromJson(json.obj('data'));
  EvidenceReview _evidence(Json json) => EvidenceReview.fromJson(json.obj('data'));
  CashDay _cash(Json json) => CashDay.fromJson(json.obj('data'));
  Deliverable _deliverable(Json json) => Deliverable.fromJson(json.obj('data'));
}
