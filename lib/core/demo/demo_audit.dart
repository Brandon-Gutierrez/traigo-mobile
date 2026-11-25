/// El historial de la demo. En el backend lo escribe la propia base; aquí
/// queda lo que se hace en la app, más unas entradas de ejemplo.
library;

import '../../features/control/domain/admin.dart';
import '../network/paged_result.dart';

class DemoAudit {
  DemoAudit({required this._now}) {
    DateTime dec(int day, int hour, int minute) => DateTime(2026, 12, day, hour, minute);
    for (final (at, actor, description) in [
      (dec(4, 9, 12), 'Isaí', 'Hizo un conteo: 1 producto con diferencia'),
      (dec(5, 17, 2), 'Dirección', 'Autorizó el precio de Tomatodos de Ronaldo: Bs 87 → Bs 89'),
      (dec(5, 18, 30), 'Isaí', 'Envió el cierre de caja del sábado 5 dic'),
      (dec(6, 9, 50), 'Jime', 'Confirmó el pago N-1043 (Bs 2.016)'),
      (dec(6, 10, 42), 'Jime', 'Cargó el valor real de «Pedidos propios efectivamente pagados» de Alison: 4'),
    ]) {
      _add(at, actor, description);
    }
  }

  static const pageSize = 30;

  final DateTime Function() _now;
  final List<AuditEntry> _entries = [];

  void log(String actor, String description) => _add(_now(), actor, description);

  void _add(DateTime at, String actor, String description) => _entries.add(AuditEntry(
        id: '${_entries.length + 1}',
        at: at,
        actorName: actor,
        description: description,
      ));

  /// Lo más nuevo primero.
  PagedResult<AuditEntry> page(int page) {
    final all = _entries.reversed.toList()..sort((a, b) => b.at.compareTo(a.at));
    return PagedResult(
      items: all.skip((page - 1) * pageSize).take(pageSize).toList(),
      page: page,
      lastPage: all.isEmpty ? 1 : (all.length + pageSize - 1) ~/ pageSize,
      total: all.length,
    );
  }
}
