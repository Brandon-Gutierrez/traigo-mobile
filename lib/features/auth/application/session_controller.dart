import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../domain/auth.dart';

/// Sesión del vendedor: `null` = no ha ingresado.
///
/// - Al abrir la app intenta recuperar la sesión con el token guardado.
/// - Si no hay internet al abrir, queda en error (no se cierra la sesión).
/// - Si la API responde 401 mientras se usa, la sesión se cierra sola.
final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, Session?>(SessionController.new);

class SessionController extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() {
    ref.listen(sessionExpiredProvider, (_, _) {
      if (state.value != null) expire();
    });
    return ref.read(authRepositoryProvider).restore();
  }

  /// Lanza [ApiException] si falla; el formulario de ingreso la muestra.
  Future<void> login({required String code, required String pin}) async {
    final session = await ref.read(authRepositoryProvider).login(
          code: code,
          pin: pin,
          deviceName: 'Traigo Vendedores (${defaultTargetPlatform.name})',
        );
    // Se recuerda el código (no el PIN) para precargarlo la próxima vez.
    await ref.read(lastCodeStorageProvider).write(session.seller.code);
    state = AsyncData(session);
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }

  /// Token vencido o revocado: se borra y se vuelve al ingreso.
  Future<void> expire() async {
    await ref.read(tokenStorageProvider).clear();
    state = const AsyncData(null);
  }
}
