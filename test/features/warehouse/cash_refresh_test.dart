import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/core/demo/demo_backend.dart';
import 'package:traigo/core/demo/demo_repositories.dart';
import 'package:traigo/core/money/money.dart';
import 'package:traigo/core/network/api_exception.dart';
import 'package:traigo/core/providers.dart';
import 'package:traigo/features/warehouse/domain/warehouse.dart';

import '../../support/sales_helpers.dart';

/// La caja de la demo, a la que después de un rato le llega un cobro con
/// tarjeta de la tienda web.
class CardArrivesRepository extends DemoWarehouseRepository {
  CardArrivesRepository(DemoBackend backend) : super(backend, Duration.zero);

  bool arrived = false;

  @override
  Future<CashDay> cashToday() async {
    final day = await super.cashToday();
    if (!arrived) {
      return _copy(day, [
        // Sin cobros en efectivo todavía: el cero se pone solo.
        for (final l in day.lines)
          l.method == PaymentMethod.cash
              ? CashLine(method: l.method, ordersCount: 0, expected: Money.zero)
              : l,
      ]);
    }
    return _copy(day, [
      ...day.lines,
      CashLine(method: PaymentMethod.card, ordersCount: 1, expected: Money.parse('50')),
    ]);
  }

  static CashDay _copy(CashDay day, List<CashLine> lines) => CashDay(
        businessDate: day.businessDate,
        status: day.status,
        collected: day.collected,
        paidOrders: day.paidOrders,
        pendingOrders: day.pendingOrders,
        lines: lines,
        pending: day.pending,
      );
}

/// La caja a la que le entra otro efectivo justo al enviarla: como el
/// servidor, responde que no cuadra y desde ahí trae el monto nuevo.
class CashArrivesOnSendRepository extends DemoWarehouseRepository {
  CashArrivesOnSendRepository(DemoBackend backend) : super(backend, Duration.zero);

  bool arrived = false;

  @override
  Future<CashDay> cashToday() async {
    final day = await super.cashToday();
    if (!arrived) return day;
    return CardArrivesRepository._copy(day, [
      for (final l in day.lines)
        l.method == PaymentMethod.cash
            ? CashLine(
                method: l.method,
                ordersCount: l.ordersCount + 1,
                expected: l.expected + Money.parse('87'),
              )
            : l,
    ]);
  }

  @override
  Future<CashDay> sendClosing(NewCashClosing closing) async {
    arrived = true;
    throw const ValidationException(
      code: 'difference_needs_note',
      message: 'La caja no cuadra: explica la diferencia.',
    );
  }
}

void main() {
  testWidgets('si el servidor ve una diferencia, trae los montos nuevos', (tester) async {
    final repo = CashArrivesOnSendRepository(DemoBackend()..login('ISA-03', '1234'));
    await openTab(tester, 'ISA-03', 'Caja',
        height: 2400, overrides: [warehouseRepositoryProvider.overrideWithValue(repo)]);

    Finder inputOf(String method) => find.descendant(
          of: find.byKey(ValueKey('cash-$method')),
          matching: find.byType(TextField),
        );
    for (final (method, amount) in const [('qr', '563'), ('transfer', '2016'), ('cash', '836')]) {
      await tester.enterText(inputOf(method), amount);
    }
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar cierre a Jime'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Enviar'));
    await tester.pumpAndSettle();

    expect(find.text('La caja no cuadra: explica la diferencia.'), findsOneWidget);
    expect(find.text('923'), findsOneWidget, reason: 'lo esperado ya trae el cobro nuevo');
    expect(tester.widget<TextField>(inputOf('cash')).controller!.text, '836',
        reason: 'lo escrito se conserva');
    expect(find.text('Explica la diferencia'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('al actualizar, aparece la tarjeta y el cero automático se limpia',
      (tester) async {
    final repo = CardArrivesRepository(DemoBackend()..login('ISA-03', '1234'));
    await openTab(tester, 'ISA-03', 'Caja',
        height: 2400, overrides: [warehouseRepositoryProvider.overrideWithValue(repo)]);

    String textOf(String method) => tester
        .widget<TextField>(find.descendant(
          of: find.byKey(ValueKey('cash-$method')),
          matching: find.byType(TextField),
        ))
        .controller!
        .text;

    expect(textOf('cash'), '0');
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('cash-qr')),
        matching: find.byType(TextField),
      ),
      '563',
    );
    await tester.pumpAndSettle();

    repo.arrived = true;
    await tester.fling(find.byType(ListView), const Offset(0, 600), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Tarjeta'), findsOneWidget);
    expect(textOf('qr'), '563', reason: 'lo escrito se conserva');
    expect(textOf('cash'), isEmpty, reason: 'ya hay un cobro en efectivo');
    expect(textOf('card'), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
