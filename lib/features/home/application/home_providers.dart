import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/session_controller.dart';
import '../domain/home.dart';

/// Inicio del equipo. Se carga al abrir y al deslizar para actualizar.
///
/// Depende de quién tiene la sesión: si sale una persona y entra otra, no
/// queda ningún dato de la anterior.
///
/// Quien registre una venta o suba una evidencia debe invalidarlo
/// (`ref.invalidate(teamHomeProvider)`) para que las cifras se actualicen.
final teamHomeProvider = FutureProvider<TeamHome>((ref) {
  ref.watch(sessionControllerProvider.select((s) => s.value?.member.id));
  return ref.watch(homeRepositoryProvider).load();
});
