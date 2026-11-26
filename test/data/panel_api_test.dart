import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/core/money/money.dart';
import 'package:traigo/core/network/api_exception.dart';
import 'package:traigo/features/control/data/admin_api_repository.dart';
import 'package:traigo/features/control/data/payouts_api_repository.dart';
import 'package:traigo/features/control/data/review_api_repository.dart';
import 'package:traigo/features/control/domain/admin.dart';
import 'package:traigo/features/control/domain/review.dart';
import 'package:traigo/features/management/data/management_api_repository.dart';
import 'package:traigo/features/management/domain/authorizations.dart';
import 'package:traigo/features/team/domain/bonus.dart';

import '../fixtures/panel_samples.dart';
import '../fixtures/team_samples.dart';
import '../support/fake_http_adapter.dart';

void main() {
  late ApiHarness h;

  setUp(() => h = ApiHarness());

  String path() => h.adapter.last.uri.path.replaceFirst('/api/v1', '');

  group('bandeja de Jime', () {
    test('lista lo pendiente y filtra por tipo', () async {
      h.adapter.reply(200, pendingResponse);

      final items = await ReviewApiRepository(h.api).pending(type: PendingType.payment);

      expect(path(), '/control/pending');
      expect(h.adapter.last.uri.queryParameters, {'type': 'payment'});
      expect(items.first.type, PendingType.cashClosing);
      expect(items.last.amount, Money.parse('90'));
    });

    test('revisa, confirma y rechaza un pago', () async {
      h.adapter
        ..reply(200, paymentReviewResponse)
        ..reply(200, paymentReviewResponse)
        ..reply(200, paymentReviewResponse);
      final repo = ReviewApiRepository(h.api);

      final review = await repo.payment('pay-9');
      expect(review.referenceUnique, isTrue);
      expect(review.amountMatchesOrder, isTrue);

      await repo.confirmPayment('pay-9', amountMatches: true, destinationOk: true);
      expect(path(), '/control/payments/pay-9/confirm');
      expect(h.adapter.last.data, confirmPaymentRequest);

      await repo.rejectPayment('pay-9', reason: 'No se ve el monto');
      expect(path(), '/control/payments/pay-9/reject');
    });

    test('aprobar lo propio lo rechaza el servidor', () async {
      h.adapter.reply(409, {'message': 'No puedes aprobar lo propio.', 'code': 'own_record'});

      await expectLater(
        ReviewApiRepository(h.api).validateResult('r-1', actual: 1),
        throwsA(isA<ConflictException>().having((e) => e.code, 'code', 'own_record')),
      );
    });

    test('valida o pide otra evidencia', () async {
      h.adapter
        ..reply(200, evidenceReviewResponse)
        ..reply(200, evidenceReviewResponse)
        ..reply(200, evidenceReviewResponse);
      final repo = ReviewApiRepository(h.api);

      final review = await repo.evidence('r-44');
      expect(review.memberName, 'Alison');
      expect(review.evidence, hasLength(1));

      await repo.validateResult('r-44', actual: 1);
      expect(path(), '/control/kpi-results/r-44/validate');
      expect(h.adapter.last.data, {'actual': 1.0, 'note': null});

      await repo.observeResult('r-44', note: 'Falta el comprobante');
      expect(path(), '/control/kpi-results/r-44/observe');
    });

    test('valida la caja y las entregas', () async {
      h.adapter
        ..reply(200, cashDayResponse)
        ..reply(200, cashDayResponse)
        ..reply(200, {
          'data': [deliverableJson],
        })
        ..reply(200, deliverableResponse);
      final repo = ReviewApiRepository(h.api);

      await repo.cashClosing('cc-1');
      await repo.validateCashClosing('cc-1');
      expect(path(), '/control/cash-closings/cc-1/validate');

      expect(await repo.deliverables(), hasLength(1));
      await repo.validateDeliverable('d-1', deliveredOn: DateTime(2026, 11, 29));
      expect(h.adapter.last.data, {'delivered_on': '2026-11-29'});
    });

    test('registra devoluciones y ventas duplicadas', () async {
      h.adapter
        ..reply(204, {})
        ..reply(204, {});
      final repo = ReviewApiRepository(h.api);

      await repo.returnOrder('o-1040', reason: 'Llegó golpeado');
      expect(path(), '/control/orders/o-1040/return');
      expect(h.adapter.last.data, returnOrderRequest);

      await repo.markDuplicate('o-1049', originalOrderId: 'o-1048');
      expect(path(), '/control/orders/o-1049/duplicate');
      expect(h.adapter.last.data, duplicateOrderRequest);
    });

    test('busca pedidos y abre uno con lo que se puede hacer', () async {
      h.adapter
        ..reply(200, controlOrdersResponse)
        ..reply(200, controlOrderResponse)
        ..reply(200, controlOrdersResponse);
      final repo = ReviewApiRepository(h.api);

      final page = await repo.orders(search: '  mariela ');
      expect(path(), '/control/orders');
      expect(h.adapter.last.uri.queryParameters, {'search': 'mariela', 'page': '1'});
      expect(page.items.first.sellerName, 'Alison');
      expect(page.items.last.sellerName, isNull, reason: 'tienda web');

      final order = await repo.order('o-1046');
      expect(path(), '/control/orders/o-1046');
      expect(order.canMarkDuplicate, isTrue);
      expect(order.canReturn, isFalse);
      expect(order.detail.lines.single.quantity, 2);

      await repo.orders(search: ' ');
      expect(h.adapter.last.uri.queryParameters, {'page': '1'});
    });

    test('lee la semana de un integrante para cargar sus valores', () async {
      h.adapter.reply(200, myWeekResponse);

      final week = await ReviewApiRepository(h.api).memberWeek('4', weekNumber: 1);

      expect(path(), '/control/members/4/week');
      expect(h.adapter.last.uri.queryParameters, {'week': '1'});
      expect(week.indicators, isNotEmpty);
    });
  });

  group('cierre, bono y comisiones', () {
    test('si queda alguien sin resolver, el servidor no deja enviar', () async {
      h.adapter.reply(409, {
        'message': 'Sistemas 1 sigue pendiente: valida sus datos o ciérralo.',
        'code': 'pending_members',
      });

      await expectLater(
        PayoutsApiRepository(h.api).sendWeeklyClosing(1, duplicatesCleared: true),
        throwsA(isA<ConflictException>().having((e) => e.code, 'code', 'pending_members')),
      );
      expect((h.adapter.last.data as Map)['close_pending'], isEmpty);
    });

    test('cumplimiento: cuántos puntos faltan', () async {
      h.adapter.reply(200, complianceResponse);

      final week = await PayoutsApiRepository(h.api).compliance();
      final rows = week.rows;

      expect((week.weekNumber, week.currentWeek), (1, 2));

      expect(rows.first.compliance, Compliance.pending);
      expect(rows.first.deliverablesOnTime, 2);
      expect(rows.first.missingPoints, isNull);
      expect(rows.last.missingPoints, 5);
    });

    test('lee y envía el cierre semanal', () async {
      h.adapter
        ..reply(200, weeklyClosingResponse)
        ..reply(200, weeklyClosingResponse);
      final repo = PayoutsApiRepository(h.api);

      final closing = await repo.weeklyClosing(weekNumber: 1);
      expect(closing.direction.ok, isFalse);
      expect(closing.sendableFrom, DateTime(2026, 12, 7));
      final waiting = closing.pendingMembers.single;
      expect(waiting.name, 'Sistemas 1');
      expect(waiting.pendingReason, '2 de 4 entregas validadas');

      await repo.sendWeeklyClosing(
        1,
        duplicatesCleared: true,
        closePending: {waiting.id: 'Solo 2 de sus 4 entregas quedaron validadas.'},
      );
      expect(path(), '/control/weekly-closing/1/send');
      expect(h.adapter.last.data, sendClosingRequest);
    });

    test('lee el bono y marca un pago', () async {
      h.adapter
        ..reply(200, bonusResponse)
        ..reply(200, bonusResponse);
      final repo = PayoutsApiRepository(h.api);

      final bonus = await repo.bonus();
      expect(bonus.level, BonusLevel.complete);
      expect(bonus.payable, Money.parse('1050'));
      expect(bonus.members.last.compliance, Compliance.fails);
      expect(bonus.members.last.amount, Money.zero);
      expect(bonus.members.last.closedReason, contains('4 entregas'));
      expect(bonus.members.first.closedReason, isNull);
      expect(bonus.readyToPay, isFalse, reason: 'falta Dirección');

      await repo.markBonusPaid(1, 'm-2');
      expect(path(), '/control/bonus/1/members/m-2/paid');
    });

    test('lee las comisiones del mes, con devoluciones y % pendientes', () async {
      h.adapter
        ..reply(200, commissionsResponse)
        ..reply(200, commissionsResponse);
      final repo = PayoutsApiRepository(h.api);

      final month = await repo.commissions('2026-12');
      expect(h.adapter.last.uri.queryParameters, {'month': '2026-12'});
      expect(month.ratesPending, isTrue);
      expect(month.total, isNull);
      expect(month.members.last.adjustments, Money.parse('-45'));

      await repo.sendCommissions('2026-12');
      expect(path(), '/control/commissions/2026-12/send');
    });
  });

  group('precios, historial y accesos', () {
    test('lee la ficha de precio y envía solo lo que cambia', () async {
      h.adapter
        ..reply(200, priceSheetResponse)
        ..reply(201, priceSheetResponse);
      final repo = AdminApiRepository(h.api);

      final sheet = await repo.priceSheet('p-8107');
      expect(sheet.current.commissionPct, isNull);
      expect(sheet.pendingChange?.proposed.priceUnit, Money.parse('89'));
      expect(sheet.pendingChange?.proposed.wholesaleMinQty, isNull);

      await repo.proposePrice(
        'p-8107',
        PriceValues(priceUnit: Money.parse('89'), priceWholesale: Money.parse('84')),
      );
      expect(path(), '/control/products/p-8107/price-changes');
      expect(h.adapter.last.data, priceChangeRequest);
    });

    test('historial paginado y estado del respaldo', () async {
      h.adapter
        ..reply(200, auditResponse)
        ..reply(200, systemStatusResponse);
      final repo = AdminApiRepository(h.api);

      final audit = await repo.audit();
      expect(audit.hasMore, isTrue);
      expect(audit.items.single.actorName, 'Jime');
      expect((await repo.systemStatus()).lastBackupAt, isNotNull);
    });

    test('descarga un reporte como archivo', () async {
      h.adapter.reply(200, {'xlsx': true});

      final bytes =
          await AdminApiRepository(h.api).downloadReport(ReportType.week, period: '1');

      expect(path(), '/control/reports/week');
      expect(h.adapter.last.uri.queryParameters, {'period': '1'});
      expect(bytes, isNotEmpty);
    });

    test('un error al descargar conserva el mensaje del servidor', () async {
      h.adapter.reply(422, {'message': 'Esa semana todavía no empezó.'});

      await expectLater(
        AdminApiRepository(h.api).downloadReport(ReportType.week, period: '7'),
        throwsA(isA<ValidationException>()
            .having((e) => e.message, 'message', 'Esa semana todavía no empezó.')),
      );
    });

    test('lista las cuentas del equipo', () async {
      h.adapter.reply(200, teamAccountsResponse);

      final accounts = await AdminApiRepository(h.api).members();

      expect(path(), '/control/members');
      expect(accounts.map((a) => a.code), ['AIL-02', 'ALI-04']);
    });

    test('restablece un PIN y cierra sesiones', () async {
      h.adapter
        ..reply(204, {})
        ..reply(204, {});
      final repo = AdminApiRepository(h.api);

      await repo.resetPin('m-4', '4821');
      expect(path(), '/control/members/m-4/pin');
      expect(h.adapter.last.data, {'pin': '4821'});

      await repo.revokeSessions('m-4');
      expect(path(), '/control/members/m-4/revoke-sessions');
    });
  });

  test('Dirección ve lo pendiente, el detalle, aprueba o devuelve', () async {
    h.adapter
      ..reply(200, authorizationsResponse)
      ..reply(200, authorizationDetailResponse)
      ..reply(204, {})
      ..reply(204, {});
    final repo = ManagementApiRepository(h.api);

    final items = await repo.pending();
    expect(items.single.type, AuthorizationType.weeklyBonus);

    final detail = await repo.detail(AuthorizationType.weeklyBonus, '1');
    expect(path(), '/management/authorizations/weekly_bonus/1');
    expect(detail.canApprove, isTrue);
    expect(detail.blockedReason, isNull);
    expect(detail.unpaid.first.reason, 'KPI 85 % de 90 %');
    expect(detail.unpaid.last.reason, startsWith('Cerrado por Jime'));

    await repo.approve(AuthorizationType.priceChange, 'pc-1');
    expect(path(), '/management/authorizations/price_change/pc-1/approve');

    await repo.sendBack(AuthorizationType.commissions, '2026-12', reason: 'Revisar Kim');
    expect(path(), '/management/authorizations/commissions/2026-12/return');
    expect(h.adapter.last.data, {'reason': 'Revisar Kim'});
  });
}
