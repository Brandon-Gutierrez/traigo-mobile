import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'chamfer.dart';

/// Pantalla provisional de las fases que todavía no se construyen. Dice qué
/// habrá ahí; se reemplaza por el diseño real en su fase.
class PhasePlaceholder extends StatelessWidget {
  const PhasePlaceholder({
    super.key,
    required this.title,
    required this.phase,
    required this.summary,
  });

  final String title;
  final int phase;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppText.display(30, height: 1.1)),
            const SizedBox(height: 6),
            Text('Llega en la fase $phase.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            ChamferBox(
              color: AppColors.alt,
              child: Text(summary, style: AppText.body(15, FontWeight.w400, height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }
}
