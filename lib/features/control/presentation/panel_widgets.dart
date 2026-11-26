/// Piezas que comparten las pantallas del panel.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ficha.dart';
import '../../orders/presentation/order_widgets.dart';

/// Cambiar de semana en el panel. Sin elegir, el servidor abre la que toca;
/// [chosen] es la elegida a mano.
class WeekNav extends StatelessWidget {
  const WeekNav({
    super.key,
    required this.shown,
    required this.current,
    required this.onShow,
    this.chosen,
    this.pendingLabel = 'Ir a la que falta cerrar',
  });

  final int shown;
  final int current;
  final int? chosen;
  final String pendingLabel;
  final void Function(int? week) onShow;

  @override
  Widget build(BuildContext context) {
    final links = [
      if (shown > 1) TextLink('‹ Semana anterior', onTap: () => onShow(shown - 1)),
      if (shown < current) TextLink('Semana siguiente ›', onTap: () => onShow(shown + 1)),
      if (chosen != null) TextLink(pendingLabel, onTap: () => onShow(null)),
    ];
    return links.isEmpty ? const SizedBox.shrink() : Wrap(spacing: 20, children: links);
  }
}

/// «hace 12 min», «hace 3 h», «ayer 18:30» o «4 dic».
String timeAgo(DateTime at, DateTime now) {
  final local = at.toLocal();
  final elapsed = now.difference(local);
  if (DateUtils.isSameDay(local, now)) {
    if (elapsed.inMinutes < 1) return 'hace un momento';
    if (elapsed.inMinutes < 60) return 'hace ${elapsed.inMinutes} min';
    return 'hace ${elapsed.inHours} h';
  }
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  if (DateUtils.isSameDay(local, yesterday)) return 'ayer ${clockTime(local)}';
  return dayLabel(local, now);
}

/// Una línea de revisión: qué se mira, su valor y si está bien.
class CheckRow extends StatelessWidget {
  const CheckRow({super.key, required this.label, required this.value, required this.mark});

  final String label;
  final String value;
  final Widget mark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.rule, width: 2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.body(13, FontWeight.w400, color: AppColors.muted)),
                Text(value, style: AppText.mono(15, weight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Flexible(child: mark),
        ],
      ),
    );
  }
}

/// Una casilla del diseño. [onChanged] nulo = la marca el sistema.
class SquareCheck extends StatelessWidget {
  const SquareCheck({super.key, required this.checked, this.onChanged, required this.label});

  final bool checked;
  final ValueChanged<bool>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    final box = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: checked ? AppColors.violet : AppColors.alt,
        border: const Border(bottom: BorderSide(color: AppColors.ink, width: 3)),
      ),
      child: checked ? const Icon(Icons.check, size: 20, color: AppColors.bg) : null,
    );
    return Semantics(
      checked: checked,
      enabled: onChanged != null,
      label: label,
      excludeSemantics: true,
      onTap: onChanged == null ? null : () => onChanged(!checked),
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged(!checked),
        child: Padding(padding: const EdgeInsets.all(8), child: box),
      ),
    );
  }
}

/// Una fila de «Más» o de una lista con ícono.
class MenuRow extends StatelessWidget {
  const MenuRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// `null` = solo informa.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.rule, width: 2)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              color: AppColors.alt,
              child: Icon(icon, size: 22, color: AppColors.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.body(15.5, FontWeight.w600)),
                  Text(
                    subtitle,
                    style: AppText.body(12.5, FontWeight.w400, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            if (onTap != null) const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

/// Texto pequeño y apagado de explicación.
class HintText extends StatelessWidget {
  const HintText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppText.body(12.5, FontWeight.w400, color: AppColors.muted, height: 1.35),
      );
}
