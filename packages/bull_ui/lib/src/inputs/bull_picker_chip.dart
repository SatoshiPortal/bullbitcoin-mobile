import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:material_ui/material_ui.dart';

/// One choice of a [BullPickerMenu] or [BullPickerChip].
class BullPickerItem<T> {
  const BullPickerItem({required this.value, required this.label});

  /// The value reported to `onChanged`.
  final T value;

  /// The text shown in the menu, and in a chip once selected.
  final String label;
}

/// Opens a menu of [items] when [child] is tapped, the selected one in bold.
///
/// The menu of every inline picker (language, currency), whatever [child]
/// looks like; [BullPickerChip] is the bordered default.
class BullPickerMenu<T> extends StatelessWidget {
  const BullPickerMenu({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    required this.child,
    this.tooltip,
  });

  /// The choices, in menu order.
  final List<BullPickerItem<T>> items;

  /// The selected value.
  final T value;

  /// Fired with the picked value, also when it equals [value].
  final ValueChanged<T> onChanged;

  /// What the user taps to open the menu.
  final Widget child;

  /// Accessible name of the picker.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium;
    return PopupMenuButton<T>(
      initialValue: value,
      tooltip: tooltip,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.5,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.bullShapes.card),
      ),
      itemBuilder: (context) => [
        for (final item in items)
          PopupMenuItem<T>(
            value: item.value,
            child: Text(
              item.label,
              style: textStyle?.copyWith(
                fontWeight: item.value == value
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
          ),
      ],
      onSelected: onChanged,
      child: child,
    );
  }
}

/// A borderless chip that shows the selected choice and opens a
/// [BullPickerMenu]: the inline picker of a settings row, flush with its
/// trailing edge.
class BullPickerChip<T> extends StatelessWidget {
  const BullPickerChip({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.icon,
    this.tooltip,
  });

  /// The choices, in menu order.
  final List<BullPickerItem<T>> items;

  /// The selected value; its item's label is shown in the chip.
  final T value;

  /// Fired with the picked value, also when it equals [value].
  final ValueChanged<T> onChanged;

  /// Optional glyph drawn before the label.
  final IconData? icon;

  /// Accessible name of the picker.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final textStyle = Theme.of(context).textTheme.bodyMedium;
    final selected = items.where((item) => item.value == value).firstOrNull;
    return BullPickerMenu<T>(
      items: items,
      value: value,
      onChanged: onChanged,
      tooltip: tooltip,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon case final glyph?) ...[
              Icon(glyph, size: 18, color: colors.onSurface),
              const SizedBox(width: 8),
            ],
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.3,
              ),
              child: Text(
                selected?.label ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textStyle?.copyWith(color: colors.onSurface),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: colors.onSurface),
          ],
        ),
      ),
    );
  }
}
