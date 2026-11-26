import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/demo/demo_backend.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/cut_button.dart';
import '../../../core/ui/rise_in.dart';
import '../application/session_controller.dart';
import 'auth_frame.dart';
import 'pin_pad.dart';

/// Ingreso con código de integrante + PIN de 4 números.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _pinLength = 4;

  final _code = TextEditingController();
  String _pin = '';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
    _prefillLastCode();
  }

  /// Si ya ingresó antes en este celular, el código viene escrito.
  Future<void> _prefillLastCode() async {
    final last = await ref.read(lastCodeStorageProvider).read();
    if (mounted && last != null && _code.text.isEmpty) {
      _code.text = last;
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _addDigit(String digit) {
    if (_busy || _pin.length >= _pinLength) return;
    FocusScope.of(context).unfocus();
    // El error se queda hasta el próximo intento: está encima del teclado y, si
    // se quitara aquí, las teclas se moverían mientras la persona escribe.
    setState(() => _pin += digit);
  }

  void _backspace() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  /// Por qué todavía no se puede entrar, o `null` si ya se puede.
  String? get _blockedReason {
    if (_code.text.trim().isEmpty) return 'Escribe tu código';
    final missing = _pinLength - _pin.length;
    return missing > 0 ? missingDigitsLabel(missing) : null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionControllerProvider.notifier).login(
            code: _code.text.trim(),
            pin: _pin,
          );
      // El router detecta la sesión (o el segundo paso) y navega solo.
    } on ApiException catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _error = e.message;
          _pin = '';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final blocked = _blockedReason;
    final error = _error;

    return AuthFrame(
      title: 'Ingresa a Traigo',
      description: 'Escribe tu código de integrante y tu PIN de 4 números. '
          'Si lo olvidaste, pídeselo a Jime.',
      children: [
        const SizedBox(height: 16),
        RiseIn(
          delay: const Duration(milliseconds: 140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('CÓDIGO', style: AppText.label()),
              const SizedBox(height: 5),
              TextField(
                controller: _code,
                enabled: !_busy,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
                  LengthLimitingTextInputFormatter(16),
                ],
                style: AppText.mono(18, weight: FontWeight.w700, letterSpacing: 1),
                decoration: const InputDecoration(hintText: 'ALI-04'),
              ),
              const SizedBox(height: 14),
              Text('PIN', style: AppText.label()),
              const SizedBox(height: 6),
              DigitBoxes(value: _pin, length: _pinLength, semanticName: 'PIN'),
            ],
          ),
        ),
        if (error != null) ...[const SizedBox(height: 14), FormError(error)],
        const SizedBox(height: 18),
        RiseIn(
          delay: const Duration(milliseconds: 200),
          child: PinPad(onDigit: _addDigit, onBackspace: _backspace),
        ),
        const SizedBox(height: 16),
        CutButton(
          label: _busy ? 'Ingresando…' : (blocked ?? 'Entrar'),
          onPressed: blocked == null ? _submit : null,
          busy: _busy,
        ),
        if (config.isDemo) ...[
          const SizedBox(height: 16),
          Text(
            'Modo demo · PIN ${DemoBackend.pin}\n'
            '${DemoBackend.members.map((m) => m.code).join(' · ')}',
            textAlign: TextAlign.center,
            style: AppText.mono(12, color: AppColors.muted),
          ),
        ] else if (kDebugMode && config.mode == DataMode.live) ...[
          const SizedBox(height: 16),
          Text(
            'API: ${config.baseUrl}',
            textAlign: TextAlign.center,
            style: AppText.mono(12, color: AppColors.muted),
          ),
        ],
      ],
    );
  }
}
