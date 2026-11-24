import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/demo/demo_backend.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/ui/hard_button.dart';
import '../../../core/ui/rise_in.dart';
import '../../../core/ui/traigo_logo.dart';
import '../application/session_controller.dart';
import 'pin_pad.dart';

/// Ingreso con código de vendedor + PIN de 4 números.
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

  /// Si el vendedor ya ingresó antes, el código viene escrito.
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
    setState(() {
      _pin += digit;
      _error = null;
    });
  }

  void _backspace() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  /// Por qué todavía no se puede entrar, o `null` si ya se puede.
  String? get _blockedReason {
    if (_code.text.trim().isEmpty) return 'Escribe tu código';
    final missing = _pinLength - _pin.length;
    if (missing > 0) return 'Faltan $missing ${missing == 1 ? 'número' : 'números'}';
    return null;
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
      // El router detecta la sesión y navega solo a Inicio.
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

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RiseIn(
                child: Row(
                  children: [
                    const TraigoLogo(size: 60),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Traigo', style: AppText.body(24, FontWeight.w800, color: AppColors.ink, height: 1)),
                          const SizedBox(height: 3),
                          Text('App del equipo de ventas', style: AppText.body(14, FontWeight.w500, color: AppColors.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              RiseIn(
                delay: const Duration(milliseconds: 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ingresa a Traigo', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 32)),
                    const SizedBox(height: 8),
                    Text(
                      'Escribe tu código de vendedor y tu PIN de 4 números. '
                      'Si lo olvidaste, pídelo al administrador.',
                      style: AppText.body(15, FontWeight.w500, color: AppColors.muted, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              RiseIn(
                delay: const Duration(milliseconds: 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CÓDIGO DE VENDEDOR', style: AppText.label()),
                    const SizedBox(height: 6),
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
                      style: AppText.body(20, FontWeight.w800, color: AppColors.ink, letterSpacing: 1),
                      decoration: const InputDecoration(hintText: 'ANA-07'),
                    ),
                    const SizedBox(height: 18),
                    Text('PIN', style: AppText.label()),
                    const SizedBox(height: 6),
                    PinBoxes(filled: _pin.length),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: AppColors.redSoft,
                    child: Text(
                      _error!,
                      style: AppText.body(14, FontWeight.w700, color: AppColors.red, height: 1.3),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              RiseIn(
                delay: const Duration(milliseconds: 200),
                child: PinPad(onDigit: _addDigit, onBackspace: _backspace),
              ),
              const SizedBox(height: 22),
              HardButton(
                label: _busy ? 'Ingresando…' : (blocked ?? 'Entrar'),
                onPressed: blocked == null ? _submit : null,
                busy: _busy,
              ),
              if (config.isDemo) ...[
                const SizedBox(height: 18),
                Text(
                  'Modo demo: código ${DemoBackend.sellerCode} · PIN ${DemoBackend.sellerPin}',
                  textAlign: TextAlign.center,
                  style: AppText.body(12, FontWeight.w700, color: AppColors.muted),
                ),
              ] else if (kDebugMode && config.mode == DataMode.live) ...[
                const SizedBox(height: 18),
                Text(
                  'API: ${config.baseUrl}',
                  textAlign: TextAlign.center,
                  style: AppText.mono(12, color: AppColors.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
