/// Las reglas del panel de Jime y de Dirección en la demo (las mismas que pide
/// el contrato al backend).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/core/demo/demo_backend.dart';
import 'package:traigo/core/demo/demo_panel_repositories.dart';
import 'package:traigo/core/money/money.dart';
import 'package:traigo/core/network/api_exception.dart';
import 'package:traigo/features/auth/domain/auth.dart';
import 'package:traigo/features/control/domain/admin.dart';
import 'package:traigo/features/control/domain/payouts.dart';
import 'package:traigo/features/control/domain/review.dart';
import 'package:traigo/features/management/domain/authorizations.dart';
import 'package:traigo/features/orders/domain/orders.dart';
import 'package:traigo/features/team/domain/bonus.dart';
import 'package:traigo/features/team/domain/my_week.dart';

import '../support/panel_helpers.dart';

Matcher conflict(String code) =>
    throwsA(isA<ConflictException>().having((e) => e.code, 'code', code));
Matcher invalid([String? code]) => throwsA(
    isA<ValidationException>().having((e) => e.code, 'code', code ?? anything));
final Matcher notFound = throwsA(isA<NotFoundException>());

void main() {
  late DemoBackend backend;
  late Member alison;

  setUp(() {
    backend = DemoBackend(clock: () => DateTime(2026, 11, 24, 18));
    Member member(String code) => DemoBackend.members.firstWhere((m) => m.code == code);
    alison = member('ALI-04');
  });

  WeeklyClosing sendClosing() => backend.control
      .sendWeeklyClosing(1, duplicatesCleared: true, closePending: pendingReason);

  group('bandeja', () {
    test('junta todo, de lo más antiguo a lo más nuevo, y filtra por tipo', () {
      final items = backend.control.pending();

      expect(items, hasLength(7));
      expect(
        items.map((i) => i.createdAt),
        orderedEquals([...items.map((i) => i.createdAt)]..sort()),
      );
      int of(PendingType type) => backend.control.pending(type: type).length;
      expect(
        [for (final type in PendingType.values) of(type)],
        [3, 2, 1, 1],
      );
      final cash = backend.control.pending(type: PendingType.cashClosing).single;
      expect(cash.title, 'Isaí · cierre del sábado 5 dic');
      expect(backend.control.summary().pending.total, 7);
    });
  });

  group('pagos', () {
    test('confirmar pide revisar el monto y la cuenta, y queda en el historial', () {
      final control = backend.control;
      expect(
        () => control.confirmPayment('1046', amountMatches: false, destinationOk: true),
        invalid(),
      );

      final review =
          control.confirmPayment('1046', amountMatches: true, destinationOk: true);

      expect(review.status, PaymentStatus.confirmed);
      expect(backend.sales.order(alison, '1046').summary.status, OrderStatus.paid);
      expect(control.pending(), hasLength(6));
      expect(control.auditPage(1).items.first.description, contains('N-1046'));
      expect(
        () => control.confirmPayment('1046', amountMatches: true, destinationOk: true),
        conflict('already_reviewed'),
      );
    });

    test('rechazar pide el motivo y el pedido vuelve a «Por pagar»', () {
      final control = backend.control;
      expect(() => control.rejectPayment('1037', '  '), invalid());

      control.rejectPayment('1037', 'No se ve el monto');

      expect(control.order('1037').detail.summary.status, OrderStatus.pendingPayment);
      expect(control.pending(type: PendingType.payment), hasLength(2));
    });

    test('validar la caja confirma el efectivo de ese día', () {
      final closing = backend.control.pending(type: PendingType.cashClosing).single;

      backend.control.validateCashClosing(closing.id);

      expect(backend.control.order('1040').detail.payment?.status, PaymentStatus.confirmed);
      expect(
        () => backend.control.validateCashClosing(closing.id),
        conflict('already_reviewed'),
      );
    });
  });

  group('pedidos de todos', () {
    test('se buscan por número o cliente', () {
      final all = backend.control.orders();
      expect(all.items.first.order.createdAt.isAfter(all.items.last.order.createdAt), isTrue);
      expect(backend.control.orders(search: 'rosa mamani').items.single.order.number,
          'N-1040');
      expect(backend.control.orders(search: 'n-1037').items.single.sellerName, isNull);
    });

    test('devolver lo entregado revierte el cobro y repone el stock', () {
      final before = backend.sales.stockLevel('p-FSYB-1109W').stock;
      expect(backend.control.order('1040').canReturn, isTrue);

      backend.control.returnOrder('1040', 'Llegó golpeado');

      final order = backend.control.order('1040');
      expect(order.detail.summary.status, OrderStatus.returned);
      expect(order.voidReason, 'Llegó golpeado');
      expect(order.canReturn, isFalse);
      expect(backend.sales.stockLevel('p-FSYB-1109W').stock, before + 3);
      expect(() => backend.control.returnOrder('1040', 'otra vez'),
          conflict('invalid_status'));
    });

    test('un duplicado se anula, libera lo reservado y apunta al original', () {
      final reserved = backend.sales.stockLevel('p-A222840').reserved;

      backend.control.markDuplicate('1036', '1037');

      final order = backend.control.order('1036');
      expect(order.detail.summary.status, OrderStatus.cancelled);
      expect(order.duplicateOfNumber, 'N-1037');
      expect(backend.sales.stockLevel('p-A222840').reserved, reserved - 2);
      expect(backend.control.pending(type: PendingType.payment), hasLength(2));
      expect(() => backend.control.markDuplicate('1046', '1036'), invalid(),
          reason: 'el original no puede estar anulado');
      expect(() => backend.control.markDuplicate('1041', '1046'),
          conflict('invalid_status'),
          reason: 'con el cobro confirmado se devuelve');
    });
  });

  group('cierre semanal y bono', () {
    test('al principio no deja enviar: faltan cobros y evidencia', () {
      final closing = backend.control.weeklyClosing();

      expect(closing.paymentsReconciled.ok, isFalse);
      expect(closing.paymentsReconciled.detail, contains('comprobantes por revisar'));
      expect(closing.kpiEvidence.ok, isFalse);
      expect(closing.pendingMembers.single.name, 'Sistemas 1');
      expect(sendClosing, invalid('checks_failed'));
    });

    test('con todo revisado, falta resolver a quien está pendiente', () {
      reviewEverything(backend);
      final closing = backend.control.weeklyClosing();
      expect(closing.paymentsReconciled.ok, isTrue,
          reason: closing.paymentsReconciled.detail);
      expect(closing.kpiEvidence.ok, isTrue);

      expect(
        () => backend.control.sendWeeklyClosing(1, duplicatesCleared: false),
        invalid('checks_failed'),
      );
      expect(
        () => backend.control.sendWeeklyClosing(1, duplicatesCleared: true),
        conflict('pending_members'),
      );
      expect(
        () => backend.control.sendWeeklyClosing(1,
            duplicatesCleared: true, closePending: {'5': 'x'}),
        invalid('not_pending'),
        reason: 'Kim no está pendiente',
      );

      final sent = sendClosing();
      expect(sent.status, WeekClosingStatus.sent);
      expect(sent.pendingMembers, isEmpty);
      expect(sendClosing, conflict('closing_already_sent'));
      final sis1 = backend.control.bonus().members.firstWhere((m) => m.id == '6');
      expect(sis1.compliance, Compliance.fails);
      expect(sis1.closedReason, pendingReason['6']);
    });

    test('Dirección autoriza: la semana se cierra y Jime marca los pagos', () {
      reviewEverything(backend);
      sendClosing();
      final item = backend.control.authorizations().firstWhere(
          (a) => a.type == AuthorizationType.weeklyBonus);
      final detail = backend.control.authorization(item.type, item.id);
      expect(detail.unpaid.map((l) => l.name), containsAll(['Kim', 'Sistemas 1']));
      expect(() => backend.control.markBonusPaid(1, '2'), conflict('not_ready_to_pay'));

      backend.control.approve(item.type, item.id);

      expect(backend.control.bonus().status, WeekClosingStatus.authorized);
      final result = backend.control.pending(type: PendingType.deliverable).single;
      expect(
        () => backend.control.validateDeliverable(result.id, DateTime(2026, 11, 30)),
        conflict('week_closed'),
      );
      expect(() => backend.control.markBonusPaid(1, '5'), conflict('not_ready_to_pay'),
          reason: 'Kim no cumple');
      final passing = backend.control
          .bonus()
          .members
          .where((m) => m.compliance == Compliance.passes);
      for (final row in passing.toList()) {
        backend.control.markBonusPaid(1, row.id);
      }
      expect(backend.control.bonus().status, WeekClosingStatus.paid);
    });

    test('si Dirección lo devuelve, los cierres a mano se vuelven a indicar', () {
      reviewEverything(backend);
      sendClosing();

      backend.control.sendBack(AuthorizationType.weeklyBonus, '1', 'Revisa a Sistemas 1');

      final closing = backend.control.weeklyClosing();
      expect(closing.status, WeekClosingStatus.returned);
      expect(closing.returnReason, 'Revisa a Sistemas 1');
      expect(closing.pendingMembers.single.name, 'Sistemas 1');
    });

    test('con todas las entregas resueltas y una tarde, ya no está pendiente', () {
      Compliance sis1() => backend.control
          .summary()
          .members
          .firstWhere((m) => m.id == '6')
          .compliance;
      final member = DemoBackend.members.firstWhere((m) => m.id == '6');
      backend.control.validateDeliverable('d-2', DateTime(2026, 12, 2));
      expect(sis1(), Compliance.pending, reason: 'falta la tercera');

      backend.team.submitDeliverable(
        member,
        'd-3',
        deliveredOn: DateTime(2026, 11, 30),
        clientUuid: 'e-3',
        url: 'https://example.com/entrega-3',
      );
      backend.control.validateDeliverable('d-3', DateTime(2026, 11, 30));

      expect(sis1(), Compliance.fails);
      expect(backend.control.weeklyClosing().pendingMembers, isEmpty);
    });

    test('las entregas toman la fecha real de Jime', () {
      final late = backend.control.validateDeliverable('d-2', DateTime(2026, 12, 2));
      expect(late.status, DeliverableStatus.late);
      expect(
        () => backend.control.rejectDeliverable('d-2', 'x'),
        conflict('already_reviewed'),
      );
    });
  });

  group('comisiones', () {
    test('sin % definido no hay montos, y se envían al terminar el mes', () {
      final month = backend.control.commissions('2026-12');

      expect(month.ratesPending, isTrue);
      expect(month.total, isNull);
      expect(month.members.map((m) => m.name), ['Alison', 'Kim']);
      expect(month.settlesOn, DateTime(2026, 12, 31));
      expect(() => backend.control.sendCommissions('2026-12'),
          conflict('month_not_ended'));
    });
  });

  group('precios', () {
    test('un cambio espera a Dirección y al aprobarlo da la comisión a lo vendido', () {
      final control = backend.control;
      // La venta N-1046 (2 tomatodos de Messi) todavía no tiene %.
      control.confirmPayment('1046', amountMatches: true, destinationOk: true);
      final messi = control.priceSheet('p-8107');
      expect(messi.pendingChange, isNull);

      final sheet = control.proposePrice(
        'p-8107',
        const PriceValues(commissionPct: 5),
        reason: 'Definir la comisión',
      );
      expect(sheet.pendingChange?.proposed.commissionPct, 5);
      expect(
        () => control.proposePrice('p-8107', const PriceValues(commissionPct: 6)),
        conflict('change_pending'),
      );

      final item = control
          .authorizations()
          .firstWhere((a) => a.id == sheet.pendingChange!.id);
      control.approve(item.type, item.id);

      expect(control.priceSheet('p-8107').current.commissionPct, 5);
      expect(control.priceSheet('p-8107').pendingChange, isNull);
      expect(
        backend.sales.order(alison, '1046').commission?.amount,
        Money.parse('8.70'),
      );
      expect(control.auditPage(1).items.first.actorName, 'Dirección');
    });

    test('el mayorista no puede superar al minorista', () {
      expect(
        () => backend.control.proposePrice(
          'p-8107',
          PriceValues(priceWholesale: Money.parse('99')),
        ),
        invalid(),
      );
    });

    test('los precios nuevos se usan al vender desde que se aprueban', () {
      final pending = backend.control.authorizations().single;
      expect(pending.type, AuthorizationType.priceChange);

      backend.control.approve(pending.type, pending.id);

      expect(backend.sales.item('p-8924').priceUnit, Money.parse('89'));
    });
  });

  group('accesos', () {
    test('el PIN nuevo reemplaza al anterior y no queda en el historial', () {
      backend.control.resetPin('4', '4821');

      expect(() => backend.login('ALI-04', '1234'),
          throwsA(isA<UnauthorizedException>()));
      expect(backend.login('ALI-04', '4821'), isA<SignedIn>());
      expect(
        backend.control.auditPage(1).items.where((e) => e.description.contains('4821')),
        isEmpty,
      );
    });

    test('solo cuentas del equipo y PIN de 4 números', () {
      expect(backend.control.accounts().map((a) => a.code),
          isNot(anyOf(contains('JIM-01'), contains('DIR-08'))));
      expect(backend.control.accounts(), hasLength(6));
      expect(() => backend.control.resetPin('1', '4821'), notFound);
      expect(() => backend.control.revokeSessions('8'), notFound);
      expect(() => backend.control.resetPin('4', '12'), invalid());
    });
  });

  group('quién puede', () {
    Future<void> signIn(String code) async {
      final outcome = backend.login(code, DemoBackend.pin);
      if (outcome is NeedsSecondStep) {
        backend.verifyTwoFactor(outcome.challenge.id, DemoBackend.secondStepCode);
      }
    }

    test('la bandeja es de Jime; precios e historial también de Dirección', () async {
      final review = DemoReviewRepository(backend, Duration.zero);
      final admin = DemoAdminRepository(backend, Duration.zero);
      final management = DemoManagementRepository(backend, Duration.zero);

      await signIn('DIR-08');
      await expectLater(review.pending(), notFound);
      await expectLater(admin.members(), notFound);
      expect(await admin.priceSheet('p-8107'), isA<PriceSheet>());
      expect((await admin.audit()).items, isNotEmpty);
      expect(await management.pending(), isNotEmpty);

      await signIn('JIM-01');
      await expectLater(management.pending(), notFound);
      await expectLater(
        admin.downloadReport(ReportType.week, period: '1'),
        invalid(),
      );

      await signIn('ALI-04');
      await expectLater(admin.audit(), notFound);
    });
  });
}
