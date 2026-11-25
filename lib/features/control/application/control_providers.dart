import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/paged_result.dart';
import '../../../core/providers.dart';
import '../../auth/application/session_controller.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../home/application/home_providers.dart';
import '../../management/domain/authorizations.dart';
import '../../team/domain/my_week.dart';
import '../../warehouse/application/warehouse_providers.dart';
import '../../warehouse/domain/warehouse.dart';
import '../domain/admin.dart';
import '../domain/control_orders.dart';
import '../domain/control_summary.dart';
import '../domain/payouts.dart';
import '../domain/review.dart';

/// Resumen de Jime y Dirección.
final controlSummaryProvider = FutureProvider<ControlSummary>((ref) {
  ref.watch(sessionControllerProvider.select((s) => s.value?.member.id));
  return ref.watch(controlRepositoryProvider).summary();
});

/// Cuántas cosas hay por revisar, para la marca de la barra inferior.
final pendingCountProvider = Provider<int?>((ref) {
  return ref.watch(controlSummaryProvider).value?.pending.total;
});

/// Cada lectura del panel se vuelve a pedir si entra otra persona.
void _watchSession(Ref ref) => ref.watch(sessionMemberIdProvider);

final pendingListProvider =
    FutureProvider.autoDispose.family<List<PendingItem>, PendingType?>((ref, type) {
  _watchSession(ref);
  return ref.watch(reviewRepositoryProvider).pending(type: type);
});

final paymentReviewProvider =
    FutureProvider.autoDispose.family<PaymentReview, String>((ref, id) {
  _watchSession(ref);
  return ref.watch(reviewRepositoryProvider).payment(id);
});

final evidenceReviewProvider =
    FutureProvider.autoDispose.family<EvidenceReview, String>((ref, id) {
  _watchSession(ref);
  return ref.watch(reviewRepositoryProvider).evidence(id);
});

final cashReviewProvider = FutureProvider.autoDispose.family<CashDay, String>((ref, id) {
  _watchSession(ref);
  return ref.watch(reviewRepositoryProvider).cashClosing(id);
});

final controlDeliverablesProvider =
    FutureProvider.autoDispose<List<Deliverable>>((ref) {
  _watchSession(ref);
  return ref.watch(reviewRepositoryProvider).deliverables();
});

final memberWeekProvider = FutureProvider.autoDispose.family<MyWeek, String>((ref, id) {
  _watchSession(ref);
  return ref.watch(reviewRepositoryProvider).memberWeek(id);
});

typedef ControlOrdersQuery = ({String search, int page});

final controlOrdersProvider = FutureProvider.autoDispose
    .family<PagedResult<ControlOrderSummary>, ControlOrdersQuery>((ref, query) {
  _watchSession(ref);
  return ref
      .watch(reviewRepositoryProvider)
      .orders(search: query.search, page: query.page);
});

final controlOrderProvider =
    FutureProvider.autoDispose.family<ControlOrder, String>((ref, id) {
  _watchSession(ref);
  return ref.watch(reviewRepositoryProvider).order(id);
});

final complianceProvider = FutureProvider.autoDispose<List<ComplianceRow>>((ref) {
  _watchSession(ref);
  return ref.watch(payoutsRepositoryProvider).compliance();
});

final weeklyClosingProvider = FutureProvider.autoDispose<WeeklyClosing>((ref) {
  _watchSession(ref);
  return ref.watch(payoutsRepositoryProvider).weeklyClosing();
});

final weekBonusProvider = FutureProvider.autoDispose<WeekBonus>((ref) {
  _watchSession(ref);
  return ref.watch(payoutsRepositoryProvider).bonus();
});

/// [data] es el mes que se muestra; [previous] es el anterior solo si tuvo algo
/// que liquidar.
typedef CommissionsView = ({MonthCommissions data, String current, String? previous});

/// Las comisiones de [chosen]. Sin elegir, el mes anterior mientras no esté
/// pagado (se liquida cuando termina) y, si no, el actual.
final commissionsViewProvider = FutureProvider.autoDispose
    .family<CommissionsView, String?>((ref, chosen) async {
  _watchSession(ref);
  final repository = ref.watch(payoutsRepositoryProvider);
  final today = ref.watch(todayProvider)();
  final current = monthKey(today);
  final previousKey = monthKey(DateTime(today.year, today.month - 1));
  final previous = await repository.commissions(previousKey);
  final month = chosen ??
      (previous.hasActivity && previous.status != SettlementStatus.paid
          ? previousKey
          : current);
  return (
    data: month == previousKey ? previous : await repository.commissions(month),
    current: current,
    previous: previous.hasActivity ? previousKey : null,
  );
});

final priceSheetProvider =
    FutureProvider.autoDispose.family<PriceSheet, String>((ref, productId) {
  _watchSession(ref);
  return ref.watch(adminRepositoryProvider).priceSheet(productId);
});

final auditProvider =
    FutureProvider.autoDispose.family<PagedResult<AuditEntry>, int>((ref, page) {
  _watchSession(ref);
  return ref.watch(adminRepositoryProvider).audit(page: page);
});

final systemStatusProvider = FutureProvider.autoDispose<SystemStatus>((ref) {
  _watchSession(ref);
  return ref.watch(adminRepositoryProvider).systemStatus();
});

final teamAccountsProvider = FutureProvider.autoDispose<List<TeamAccount>>((ref) {
  _watchSession(ref);
  return ref.watch(adminRepositoryProvider).members();
});

final authorizationsProvider =
    FutureProvider.autoDispose<List<AuthorizationItem>>((ref) {
  _watchSession(ref);
  return ref.watch(managementRepositoryProvider).pending();
});

typedef AuthorizationKey = ({AuthorizationType type, String id});

final authorizationProvider = FutureProvider.autoDispose
    .family<AuthorizationDetail, AuthorizationKey>((ref, key) {
  _watchSession(ref);
  return ref.watch(managementRepositoryProvider).detail(key.type, key.id);
});

/// Una validación, un cierre o una autorización cambian todo el panel y
/// también lo que ve el equipo.
void refreshPanelData(ProviderContainer container) {
  container
    ..invalidate(controlSummaryProvider)
    ..invalidate(pendingListProvider)
    ..invalidate(paymentReviewProvider)
    ..invalidate(evidenceReviewProvider)
    ..invalidate(cashReviewProvider)
    ..invalidate(controlDeliverablesProvider)
    ..invalidate(memberWeekProvider)
    ..invalidate(controlOrdersProvider)
    ..invalidate(controlOrderProvider)
    ..invalidate(complianceProvider)
    ..invalidate(weeklyClosingProvider)
    ..invalidate(weekBonusProvider)
    ..invalidate(commissionsViewProvider)
    ..invalidate(priceSheetProvider)
    ..invalidate(auditProvider)
    ..invalidate(authorizationsProvider)
    ..invalidate(authorizationProvider)
    ..invalidate(inventoryCountsProvider)
    ..invalidate(catalogPageProvider)
    ..invalidate(productProvider)
    ..invalidate(teamHomeProvider);
}

/// Hace una acción del panel y avisa: [success] si salió bien o el motivo si no.
/// Después se actualiza todo, también si falló (algo cambió en el servidor).
/// Devuelve `true` si salió bien.
Future<bool> runPanelAction(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  try {
    await action();
    if (success != null) messenger.showSnackBar(SnackBar(content: Text(success)));
    refreshPanelData(container);
    return true;
  } on ApiException catch (e) {
    HapticFeedback.heavyImpact();
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    refreshPanelData(container);
    return false;
  }
}
