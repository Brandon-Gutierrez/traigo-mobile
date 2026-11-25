import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/session_controller.dart';
import '../domain/control_summary.dart';

/// Resumen de Jime y Dirección. Quien confirme un pago o valide algo debe
/// invalidarlo para que los pendientes se actualicen.
final controlSummaryProvider = FutureProvider<ControlSummary>((ref) {
  ref.watch(sessionControllerProvider.select((s) => s.value?.member.id));
  return ref.watch(controlRepositoryProvider).summary();
});

/// Cuántas cosas hay por revisar, para la marca de la barra inferior.
final pendingCountProvider = Provider<int?>((ref) {
  return ref.watch(controlSummaryProvider).value?.pending.total;
});
