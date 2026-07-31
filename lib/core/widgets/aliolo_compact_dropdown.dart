import 'package:flutter/material.dart';

class AlioloCompactDropdown<T> extends StatelessWidget {
  final T value;
  final Map<T, String> items;
  final ValueChanged<T?>? onChanged;
  final IconData? prefixIcon;
  final String? selectedLabel;
  final bool matchAnchorWidth;
  final double? menuWidth;
  final double verticalPadding;
  final bool useFilledSurfaceStyle;
  final Key? surfaceKey;

  const AlioloCompactDropdown({
    super.key,
    required this.value,
    required this.items,
    this.onChanged,
    this.prefixIcon,
    this.selectedLabel,
    this.matchAnchorWidth = true,
    this.menuWidth,
    this.verticalPadding = 8,
    this.useFilledSurfaceStyle = false,
    this.surfaceKey,
  });

  @override
  Widget build(BuildContext context) {
    final validatedValue =
        items.containsKey(value)
            ? value
            : (items.isNotEmpty ? items.keys.first : value);
    final label = selectedLabel ?? items[validatedValue] ?? '';

    return LayoutBuilder(
      builder: (context, box) {
        return PopupMenuButton<T>(
          constraints:
              menuWidth != null
                  ? BoxConstraints(minWidth: menuWidth!, maxWidth: menuWidth!)
                  : (matchAnchorWidth
                      ? BoxConstraints(
                        minWidth: box.maxWidth,
                        maxWidth: box.maxWidth,
                      )
                      : null),
          onSelected: onChanged,
          position: PopupMenuPosition.under,
          color: Theme.of(context).colorScheme.surface,
          itemBuilder:
              (context) =>
                  items.entries
                      .map(
                        (entry) => PopupMenuItem<T>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
          child: Container(
            key: surfaceKey,
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: verticalPadding,
            ),
            decoration: BoxDecoration(
              color:
                  useFilledSurfaceStyle
                      ? Theme.of(context).cardColor.withValues(alpha: 0.5)
                      : Theme.of(context).colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    useFilledSurfaceStyle
                        ? Colors.grey.withValues(alpha: 0.5)
                        : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                if (prefixIcon != null) ...[
                  Icon(prefixIcon, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.arrow_drop_down, size: 20, color: Colors.grey[600]),
              ],
            ),
          ),
        );
      },
    );
  }
}
