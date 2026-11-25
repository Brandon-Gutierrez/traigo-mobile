import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/brand_logo.dart';
import '../../../core/ui/rise_in.dart';

/// Marco común de las pantallas de ingreso: logo, regla gruesa, título y la
/// explicación; debajo va el formulario.
class AuthFrame extends StatelessWidget {
  const AuthFrame({
    super.key,
    required this.title,
    required this.description,
    required this.children,
    this.titleSize = 30,
  });

  final String title;
  final String description;
  final List<Widget> children;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const RiseIn(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: BrandLogo(BrandAsset.lockup, width: 220),
                ),
              ),
              const SizedBox(height: 18),
              const ColoredBox(color: AppColors.ink, child: SizedBox(height: 3)),
              const SizedBox(height: 14),
              RiseIn(
                delay: const Duration(milliseconds: 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.display(titleSize, height: 1.1)),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: AppText.body(15, FontWeight.w400, color: AppColors.muted, height: 1.4),
                    ),
                  ],
                ),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Aviso de error del formulario; el lector de pantalla lo anuncia.
class FormError extends StatelessWidget {
  const FormError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: AppColors.alt,
          border: Border(left: BorderSide(color: AppColors.alert, width: 6)),
        ),
        child: Text(
          message,
          style: AppText.body(14, FontWeight.w600, color: AppColors.alert, height: 1.3),
        ),
      ),
    );
  }
}

/// «Falta 1 número» / «Faltan 3 números».
String missingDigitsLabel(int missing) =>
    missing == 1 ? 'Falta 1 número' : 'Faltan $missing números';
