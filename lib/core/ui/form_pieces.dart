/// Piezas de navegación y formularios del diseño: «volver», pestañas con
/// subrayado, opciones en bloques y campos con etiqueta.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'chamfer.dart';

/// «‹ Catálogo».
class BackLink extends StatelessWidget {
  const BackLink(this.label, {super.key, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: 'Volver a $label',
        excludeSemantics: true,
        onTap: onTap,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back, size: 20, color: AppColors.violet),
                const SizedBox(width: 8),
                Text(label, style: AppText.body(15, FontWeight.w600, color: AppColors.violet)),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pestañas de filtro: la elegida va en negrita con una barra violeta. Si no
/// caben, se desplazan de lado.
class UnderlineTabs<T> extends StatelessWidget {
  const UnderlineTabs({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (value, label) in options)
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Semantics(
                button: true,
                selected: value == selected,
                child: InkWell(
                  onTap: () => onSelected(value),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: value == selected ? AppColors.violet : Colors.transparent,
                          width: 4,
                        ),
                      ),
                    ),
                    child: Text(
                      label,
                      style: AppText.body(
                        15,
                        value == selected ? FontWeight.w700 : FontWeight.w500,
                        color: value == selected ? AppColors.ink : AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Una elección entre pocas opciones, en bloques del mismo ancho. La elegida va
/// en tinta con la esquina cortada.
class ChoiceBlocks<T> extends StatelessWidget {
  const ChoiceBlocks({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<(T, String)> options;
  final T? selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (index, (value, label)) in options.indexed) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(child: _block(value, label)),
        ],
      ],
    );
  }

  Widget _block(T value, String label) {
    final on = value == selected;
    final block = Material(
      color: on ? AppColors.ink : AppColors.alt,
      child: InkWell(
        onTap: () => onSelected(value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 46),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: AppText.display(15, color: on ? AppColors.bg : AppColors.ink),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: on,
      child: on ? ClipPath(clipper: const ChamferClipper(cut: 10), child: block) : block,
    );
  }
}

/// Un valor que se elige en otra ventana (fecha, hora): parece un campo y abre
/// el selector al tocarlo.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.value,
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.placeholder = false,
  });

  final String value;
  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;

  /// Todavía no se eligió: se muestra en gris.
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: AppColors.alt,
        shape: const Border(bottom: BorderSide(color: AppColors.ink, width: 3)),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: placeholder
                          ? AppText.body(16, FontWeight.w400, color: AppColors.muted)
                          : AppText.mono(18, weight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(icon, size: 20, color: AppColors.ink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Etiqueta en mayúsculas sobre su control.
class Labeled extends StatelessWidget {
  const Labeled(this.label, {super.key, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label.toUpperCase(), style: AppText.label()),
        const SizedBox(height: 5),
        child,
      ],
    );
  }
}

/// Campo de texto con su etiqueta.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.mono = false,
    this.enabled = true,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.lines = 1,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool autofocus;

  /// Para números y códigos.
  final bool mono;
  final bool enabled;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  /// Alto mínimo en líneas, para notas largas.
  final int lines;

  @override
  Widget build(BuildContext context) {
    final style = mono
        ? AppText.mono(18, weight: FontWeight.w700)
        : AppText.body(16, FontWeight.w500);
    return Labeled(
      label,
      child: Semantics(
        key: ValueKey('field-$label'),
        label: label,
        child: TextField(
          controller: controller,
          autofocus: autofocus,
          enabled: enabled,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          style: style,
          minLines: lines,
          maxLines: lines == 1 ? 1 : lines + 2,
          decoration: InputDecoration(
            hintText: hint,
            hintMaxLines: lines,
            hintStyle: style.copyWith(color: AppColors.muted, fontWeight: FontWeight.w400),
          ),
        ),
      ),
    );
  }
}
