import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../domain/auth.dart';

/// Sesión del integrante: `null` = no ha ingresado.
///
/// - Al abrir la app intenta recuperar la sesión con el token guardado.
/// - Si no hay internet al abrir, queda en error (no se cierra la sesión).
/// - Si la API responde 401 mientras se usa, la sesión se cierra sola.
final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, Session?>(SessionController.new);

/// Segundo paso pendiente de Jime o Dirección. `null` = no hay ninguno.
final secondStepProvider =
    NotifierProvider<SecondStep, TwoFactorChallenge?>(SecondStep.new);

class SecondStep extends Notifier<TwoFactorChallenge?> {
  @override
  TwoFactorChallenge? build() => null;

  void start(TwoFactorChallenge challenge) => state = challenge;

  /// Volver al ingreso.
  void clear() => state = null;
}

class SessionController extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() {
    ref.listen(sessionExpiredProvider, (_, _) {
      if (state.value != null) expire();
    });
    return ref.read(authRepositoryProvider).restore();
  }

  static String get _deviceName => 'Traigo Equipo (${defaultTargetPlatform.name})';

  /// Primer paso: código y PIN. Lanza [ApiException] si falla; el formulario
  /// la muestra.
  Future<void> login({required String code, required String pin}) async {
    final outcome = await ref.read(authRepositoryProvider).login(
          code: code,
          pin: pin,
          deviceName: _deviceName,
        );
    switch (outcome) {
      case SignedIn(:final session):
        await _enter(session);
      case NeedsSecondStep(:final challenge):
        // El código ya pasó con su PIN: se recuerda también si se toca «Volver».
        await ref.read(lastCodeStorageProvider).write(code.trim().toUpperCase());
        ref.read(secondStepProvider.notifier).start(challenge);
    }
  }

  /// Segundo paso: el código de 6 números.
  Future<void> verifySecondStep(String code) async {
    final challenge = ref.read(secondStepProvider);
    if (challenge == null) return;
    final session = await ref.read(authRepositoryProvider).verifyTwoFactor(
          challengeId: challenge.id,
          code: code,
          deviceName: _deviceName,
        );
    await _enter(session);
  }

  Future<void> resendSecondStep() async {
    final challenge = ref.read(secondStepProvider);
    if (challenge == null) return;
    final next = await ref.read(authRepositoryProvider).resendTwoFactor(challenge.id);
    ref.read(secondStepProvider.notifier).start(next);
  }

  Future<void> _enter(Session session) async {
    // Se recuerda el código (no el PIN) para precargarlo la próxima vez.
    await ref.read(lastCodeStorageProvider).write(session.member.code);
    state = AsyncData(session);
    ref.read(secondStepProvider.notifier).clear();
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
