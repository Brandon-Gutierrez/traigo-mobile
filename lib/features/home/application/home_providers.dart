import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/session_controller.dart';
import '../domain/home.dart';

/// Resumen de Inicio. Se carga al abrir y al deslizar para actualizar.
///
/// Depende del vendedor que tiene la sesión: si se cierra sesión y entra otro,
/// no queda ningún dato del anterior.
///
/// Quien registre una venta o cancele un pedido debe invalidar este provider
/// (`ref.invalidate(homeSummaryProvider)`) para que las cifras se actualicen.
final homeSummaryProvider = FutureProvider<HomeSummary>((ref) {
  ref.watch(sessionControllerProvider.select((s) => s.value?.seller.id));
  return ref.watch(homeRepositoryProvider).load();
});
