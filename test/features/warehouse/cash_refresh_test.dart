import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/core/demo/demo_backend.dart';
import 'package:traigo/core/demo/demo_repositories.dart';
import 'package:traigo/core/money/money.dart';
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

void main() {
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
