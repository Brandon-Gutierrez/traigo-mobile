import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Pantalla provisional de las fases que todavía no se construyen.
/// Se reemplaza por el diseño real en su fase.
class PhasePlaceholder extends StatelessWidget {
  const PhasePlaceholder({
    super.key,
    required this.title,
    required this.phase,
    this.children = const [],
  });

  final String title;
  final String phase;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: text.headlineMedium),
            const SizedBox(height: 6),
            Text('Se construye en la $phase.', style: text.bodySmall),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.all(color: AppColors.ink, width: 2),
              ),
              child: Text(
                'Los datos ya llegan por el repositorio correspondiente '
                '(demo o API real). Falta el diseño de esta pantalla.',
                style: text.bodyMedium,
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}
