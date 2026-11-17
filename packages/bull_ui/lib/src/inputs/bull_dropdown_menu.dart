import 'package:bull_ui/src/inputs/bull_picker_item.dart';
import 'package:bull_ui/src/layout/gap.dart';
import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The one menu behind every Bull dropdown: a flat [BullTheme.surface] panel
/// with a hairline [BullTheme.primary] outline and the [BullShapes.input]
/// corner, opened directly under [anchor], the selected row tinted and in
/// bold. Scrolls past half the screen.
///
/// Resolves with the index of the tapped item, or null when dismissed, so an
/// item whose value is null stays distinguishable from a dismissal.
Future<int?> showBullDropdownMenu<T>({
  required BuildContext anchor,
  required List<BullPickerItem<T>> items,
  required T? value,
  bool matchAnchorWidth = false,
}) {
  final colors = anchor.bull;
  final shapes = anchor.bullShapes;
  final box = anchor.findRenderObject();
  final overlay = Navigator.of(anchor).overlay?.context.findRenderObject();
  if (box is! RenderBox || overlay is! RenderBox) return Future.value();
  final position = RelativeRect.fromRect(
    Rect.fromPoints(
      box.localToGlobal(Offset(0, box.size.height), ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    ),
    Offset.zero & overlay.size,
  );
  final selectedIndex = items.indexWhere((item) => item.value == value);
  return showMenu<int>(
    context: anchor,
    position: position,
    color: colors.surface,
    surfaceTintColor: colors.transparent,
    elevation: 0,
    menuPadding: const EdgeInsets.symmetric(vertical: BullSpacing.xs),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(shapes.input),
      side: BorderSide(
        color: colors.primary.withValues(alpha: 0.15),
        width: 0.5,
      ),
    ),
    constraints: BoxConstraints(
      minWidth: matchAnchorWidth ? box.size.width : 0,
      maxWidth: matchAnchorWidth
          ? box.size.width
          : overlay.size.width - 2 * BullSpacing.md,
      maxHeight: overlay.size.height * 0.5,
    ),
    items: [
      for (var i = 0; i < items.length; i++)
        PopupMenuItem<int>(
          value: i,
          padding: const EdgeInsets.symmetric(horizontal: BullSpacing.xs),
          child: BullDropdownRow(
            item: items[i],
            selected: i == selectedIndex,
            fillWidth: matchAnchorWidth,
          ),
        ),
    ],
  );
}

/// One row of the menu [showBullDropdownMenu] opens.
class BullDropdownRow<T> extends StatelessWidget {
  const BullDropdownRow({
    super.key,
    required this.item,
    required this.selected,
    this.fillWidth = false,
  });

  /// The choice this row shows.
  final BullPickerItem<T> item;

  /// Whether this row is the current value: tinted, in bold, in primary.
  final bool selected;

  /// Whether the tint spans the whole menu width rather than hugging the label.
  final bool fillWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final style = context.bullText.bodyMedium?.copyWith(
      color: selected ? colors.primary : colors.text,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
    );
    return Container(
      width: fillWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(
        horizontal: BullSpacing.xs,
        vertical: BullSpacing.xxs,
      ),
      decoration: selected
          ? BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(context.bullShapes.input),
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.leading case final leading?) ...[
            leading,
            const Gap(BullSpacing.xs),
          ],
          Flexible(
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}
