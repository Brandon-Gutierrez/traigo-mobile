import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/core/demo/demo_backend.dart';
import 'package:traigo/core/providers.dart';
import 'package:traigo/features/control/domain/payouts.dart';

import '../../support/sales_helpers.dart';

/// El cierre como lo da el servidor el último día de la semana 2: abre la 1,
/// que falta cerrar, y la 2 todavía no se puede enviar.
class TwoWeeksRepository implements PayoutsRepository {
  final List<int?> asked = [];

  @override
  Future<WeeklyClosing> weeklyClosing({int? weekNumber}) async {
    asked.add(weekNumber);
    final demo = DemoBackend().control.weeklyClosing();
    final shown = weekNumber ?? 1;
    const ok = ClosingCheck(ok: true, detail: 'Todo revisado');
    return WeeklyClosing(
      weekNumber: shown,
      currentWeek: 2,
      sendableFrom: shown == 1 ? DateTime(2026, 12, 1) : DateTime(2027, 1, 4),
      week: demo.week,
      status: WeekClosingStatus.open,
      paymentsReconciled: ok,
      kpiEvidence: ok,
      duplicates: demo.duplicates,
      direction: demo.direction,
      pendingMembers: const [],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Jime cambia de semana y la que no terminó no se envía todavía', (tester) async {
    final repository = TwoWeeksRepository();
    await openTab(tester, 'JIM-01', 'Cierre',
        height: 1500, overrides: [payoutsRepositoryProvider.overrideWithValue(repository)]);

    // Sin elegir: el servidor abre la que toca.
    expect(repository.asked.last, isNull);
    expect(find.text('‹ Semana anterior'), findsNothing);
    expect(find.text('Confirma los duplicados'), findsOneWidget);

    await tester.tap(find.text('Semana siguiente ›'));
    await tester.pumpAndSettle();

    expect(repository.asked.last, 2);
    expect(find.text('Se envía desde el lunes 4 ene'), findsOneWidget);
    expect(find.text('‹ Semana anterior'), findsOneWidget);
    expect(find.text('Semana siguiente ›'), findsNothing);

    await tester.tap(find.text('Ir a la que falta cerrar'));
    await tester.pumpAndSettle();

    expect(find.text('Confirma los duplicados'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
