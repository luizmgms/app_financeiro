import 'package:flutter/material.dart';
import '../../core/utils/color_utils.dart';
import '../../core/utils/icon_catalog.dart';

/// Seletor reutilizável de cor hexadecimal da paleta padrão.
class ColorPickerRow extends StatelessWidget {
  const ColorPickerRow({
    super.key,
    required this.selectedHex,
    required this.onSelected,
    this.colors = ColorUtils.presetHexColors,
  });

  final String selectedHex;
  final ValueChanged<String> onSelected;
  final List<String> colors;

  @override
  Widget build(BuildContext context) {
    final normalizedSelected = selectedHex.toUpperCase();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final hex in colors)
          Builder(
            builder: (context) {
              final color = ColorUtils.fromHex(hex);
              final isSelected = normalizedSelected == hex.toUpperCase();
              return InkWell(
                onTap: () => onSelected(hex),
                borderRadius: BorderRadius.circular(999),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : null,
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Seletor reutilizável de ícones do catálogo seguro.
class IconPickerGrid extends StatelessWidget {
  const IconPickerGrid({
    super.key,
    required this.options,
    required this.selectedIconName,
    required this.accentColor,
    required this.onSelected,
  });

  final List<IconCatalogOption> options;
  final String selectedIconName;
  final Color accentColor;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          Tooltip(
            message: option.label,
            child: InkWell(
              onTap: () => onSelected(option.name),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: option.name == selectedIconName
                      ? accentColor.withOpacity(0.16)
                      : theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: option.name == selectedIconName
                        ? accentColor
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  option.icon,
                  size: 20,
                  color: option.name == selectedIconName
                      ? accentColor
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
