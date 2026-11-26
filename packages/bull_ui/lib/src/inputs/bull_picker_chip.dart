import 'package:bull_ui/src/theme/bull_typography.dart';
import 'package:bull_ui/src/inputs/bull_dropdown_menu.dart';
import 'package:bull_ui/src/inputs/bull_picker_item.dart';
import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Opens the Bull menu ([showBullDropdownMenu]) of [items] under [child] when
/// it is tapped, the selected one in bold primary text.
///
/// The menu of every inline picker (language, currency), whatever [child]
/// looks like; [BullPickerChip] is the text-and-chevron default.
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
    final button = Material(
      type: MaterialType.transparency,
      child: Builder(
        builder: (anchor) => InkWell(
          borderRadius: BorderRadius.circular(context.bullShapes.input),
          onTap: () => _open(anchor),
          child: child,
        ),
      ),
    );
    if (tooltip case final message?) {
      return Tooltip(message: message, child: button);
    }
    return button;
  }

  Future<void> _open(BuildContext anchor) async {
    final index = await showBullDropdownMenu<T>(
      anchor: anchor,
      items: items,
      value: value,
    );
    if (index != null) onChanged(items[index].value);
  }
}

/// The selected choice as [BullTheme.primary] text with a chevron, opening a
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
    final textStyle = context.bullType.body.copyWith(color: colors.primary);
    final selected = items.where((item) => item.value == value).firstOrNull;
    return BullPickerMenu<T>(
      items: items,
      value: value,
      onChanged: onChanged,
      tooltip: tooltip,
      child: Padding(
        padding: const EdgeInsets.only(
          left: BullSpacing.md,
          top: BullSpacing.xs,
          bottom: BullSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon case final glyph?) ...[
              Icon(glyph, size: 18, color: colors.primary),
              const SizedBox(width: BullSpacing.xs),
            ],
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.3,
              ),
              child: Text(
                selected?.label ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textStyle,
              ),
            ),
            const SizedBox(width: BullSpacing.xxs),
            Icon(Icons.expand_more, size: 20, color: colors.primary),
          ],
        ),
      ),
    );
  }
}
