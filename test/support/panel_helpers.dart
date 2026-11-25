import 'package:traigo/core/demo/demo_backend.dart';
import 'package:traigo/features/control/domain/review.dart';
import 'package:traigo/features/warehouse/domain/warehouse.dart';

/// Deja los cobros y la evidencia de la semana sin nada por revisar: Jime
/// confirma los comprobantes, almacén reenvía la caja del viernes 4 y envía la
/// de hoy, y Jime valida todo.
void reviewEverything(DemoBackend backend) {
  final control = backend.control;
  final isai = DemoBackend.members.firstWhere((m) => m.code == 'ISA-03');
  for (final item in control.pending(type: PendingType.payment)) {
    control.confirmPayment(item.id, amountMatches: true, destinationOk: true);
  }
  for (final date in [DateTime(2026, 12, 4), DateTime(2026, 12, 6)]) {
    final day = backend.warehouse.cashDay(isai, date);
    backend.warehouse.sendClosing(
      isai,
      NewCashClosing(
        clientUuid: 'w-${date.day}',
        businessDate: date,
        counted: {for (final line in day.lines) line.method: line.expected},
      ),
    );
  }
  for (final item in control.pending(type: PendingType.cashClosing)) {
    control.validateCashClosing(item.id);
  }
  for (final item in control.pending(type: PendingType.evidence)) {
    control.validateResult(item.id, control.evidenceReview(item.id).indicator.target);
  }
}

/// Sistemas 1 sigue pendiente: Jime lo cierra con este motivo.
const pendingReason = {'6': 'Solo 2 de sus 4 entregas quedaron validadas.'};

/// Todo revisado y el cierre ya en manos de Dirección.
void sendWeek(DemoBackend backend) {
  reviewEverything(backend);
  backend.control
      .sendWeeklyClosing(1, duplicatesCleared: true, closePending: pendingReason);
}
