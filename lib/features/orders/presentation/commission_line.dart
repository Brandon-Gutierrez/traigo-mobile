import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../../../core/theme/app_theme.dart';

/// «Tu comisión … [% por definir]». El porcentaje de cada producto todavía no
/// está definido; cuando el servidor lo mande, se muestra solo.
class CommissionLine extends StatelessWidget {
  const CommissionLine({super.key, required this.label, this.percent, this.amount});

  final String label;

  /// % del producto (en la ficha).
  final double? percent;

  /// Monto ya calculado (en un pedido).
  final Money? amount;

  @override
  Widget build(BuildContext context) {
    final percent = this.percent;
    final value = amount?.formatFixed() ??
        (percent == null
            ? '[% por definir]'
            : '${percent.toStringAsFixed(percent.truncateToDouble() == percent ? 0 : 2)} %');
    final known = amount != null || percent != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: Text(label, style: AppText.body(14.5, FontWeight.w400))),
          const SizedBox(width: 8),
          Text(
            value,
            style: known
                ? AppText.mono(15, weight: FontWeight.w700, color: AppColors.violet)
                : AppText.mono(11.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
