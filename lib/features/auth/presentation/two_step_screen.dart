import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/demo/demo_backend.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/cut_button.dart';
import '../../../core/ui/ficha.dart';
import '../application/session_controller.dart';
import '../domain/auth.dart';
import 'auth_frame.dart';
import 'pin_pad.dart';

/// Segundo paso de Jime y Dirección: el código de verificación.
class TwoStepScreen extends ConsumerStatefulWidget {
  const TwoStepScreen({super.key});

  @override
  ConsumerState<TwoStepScreen> createState() => _TwoStepScreenState();
}

class _TwoStepScreenState extends ConsumerState<TwoStepScreen> {
  Timer? _ticker;
  String _value = '';
  bool _busy = false;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Actualiza las cuentas regresivas.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _addDigit(String digit, int length) {
    if (_busy || _value.length >= length) return;
    setState(() {
      _value += digit;
      _error = null;
    });
  }

  void _backspace() {
    if (_busy || _value.isEmpty) return;
    setState(() => _value = _value.substring(0, _value.length - 1));
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionControllerProvider.notifier).verifySecondStep(_value);
    } on ApiException catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _error = e.message;
          _value = '';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_resending) return;
    setState(() {
      _resending = true;
      _error = null;
      _value = '';
    });
    try {
      await ref.read(sessionControllerProvider.notifier).resendSecondStep();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  /// `04:32`. Nunca negativo.
  static String _clockText(Duration left) {
    final seconds = left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final TwoFactorChallenge? challenge = ref.watch(secondStepProvider);
    // Al entrar (o al volver) el router cambia de pantalla.
    if (challenge == null) return const Scaffold();

    final now = ref.watch(clockProvider)();
    final expiresIn = challenge.expiresAt.difference(now);
    final resendIn = challenge.resendAt.difference(now);
    final length = challenge.codeLength;
    final missing = length - _value.length;
    final error = _error;
    final expiry = expiresIn > Duration.zero
        ? 'Vence en ${_clockText(expiresIn)}.'
        : 'El código venció: pide uno nuevo.';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(secondStepProvider.notifier).clear();
      },
      child: AuthFrame(
        title: 'Verificación en dos pasos',
        titleSize: 28,
        description: 'Tu cuenta puede validar y autorizar pagos. Además del PIN, '
            'escribe el código de $length números que te llegó. $expiry',
        children: [
          const SizedBox(height: 18),
          Text('CÓDIGO DE VERIFICACIÓN', style: AppText.label()),
          const SizedBox(height: 6),
          DigitBoxes(
            value: _value,
            length: length,
            semanticName: 'Código de verificación',
            obscure: false,
            boxWidth: 50,
            boxHeight: 60,
            gap: 8,
          ),
          if (error != null) ...[const SizedBox(height: 14), FormError(error)],
          const SizedBox(height: 18),
          PinPad(onDigit: (d) => _addDigit(d, length), onBackspace: _backspace),
          const SizedBox(height: 14),
          CutButton(
            label: _busy
                ? 'Verificando…'
                : (missing > 0 ? missingDigitsLabel(missing) : 'Verificar'),
            onPressed: missing == 0 ? _verify : null,
            busy: _busy,
          ),
          const SizedBox(height: 6),
          Center(
            child: resendIn > Duration.zero
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'Reenviar el código en ${_clockText(resendIn)}',
                      style: AppText.body(14, FontWeight.w400, color: AppColors.muted),
                    ),
                  )
                : TextLink(_resending ? 'Enviando…' : 'Reenviar código', onTap: _resend),
          ),
          Center(
            child: TextLink(
              'Volver',
              color: AppColors.ink,
              onTap: () => ref.read(secondStepProvider.notifier).clear(),
            ),
          ),
          if (ref.watch(appConfigProvider).isDemo) ...[
            const SizedBox(height: 8),
            Text(
              'Modo demo · código ${DemoBackend.secondStepCode}',
              textAlign: TextAlign.center,
              style: AppText.mono(12, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}
