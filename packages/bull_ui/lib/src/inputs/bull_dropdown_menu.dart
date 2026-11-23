import 'package:bull_ui/src/theme/bull_typography.dart';
import 'package:bull_ui/src/inputs/bull_picker_item.dart';
import 'package:bull_ui/src/layout/gap.dart';
import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/bull_selection_fill.dart';

/// The one menu behind every Bull dropdown: a flat [BullTheme.surface] panel
/// with a hairline [BullTheme.primary] outline and the [BullShapes.input]
/// corner, opened directly under [anchor], the selected row in bold
/// [BullTheme.primary] text. Scrolls past [maxHeightFactor] of the screen;
/// the menu moves up when it would not fit under [anchor].
///
/// Resolves with the index of the tapped item, or null when dismissed, so an
/// item whose value is null stays distinguishable from a dismissal.
Future<int?> showBullDropdownMenu<T>({
  required BuildContext anchor,
  required List<BullPickerItem<T>> items,
  required T? value,
  bool matchAnchorWidth = false,
  double maxHeightFactor = 0.5,
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
      maxHeight: overlay.size.height * maxHeightFactor,
    ),
    items: [
      for (var i = 0; i < items.length; i++) ...[
        if (items[i].dividerBefore)
          const PopupMenuDivider(height: BullSpacing.xs),
        PopupMenuItem<int>(
          value: i,
          enabled: items[i].enabled,
          height: BullSpacing.xxl,
          padding: EdgeInsets.zero,
          child: Semantics(
            selected: items[i].checked == null ? i == selectedIndex : null,
            checked: items[i].checked,
            child: BullDropdownRow(
              item: items[i],
              selected: i == selectedIndex,
              fillWidth: matchAnchorWidth,
            ),
          ),
        ),
      ],
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

  /// Whether this row is the current value: in bold, in primary.
  final bool selected;

  /// Whether the row spans the whole menu width rather than hugging the label.
  final bool fillWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final style = context.bullType.body.copyWith(
      color: !item.enabled
          ? colors.textMuted
          : selected
          ? colors.primary
          : colors.text,
      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
    );
    return Container(
      color: selected ? bullSelectionFill(context) : colors.transparent,
      width: fillWidth ? double.infinity : null,
      constraints: const BoxConstraints(minHeight: BullSpacing.xxl),
      padding: const EdgeInsets.symmetric(
        horizontal: BullSpacing.md,
        vertical: BullSpacing.xxs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          if (item.checked case final checked?) ...[
            SizedBox(
              width: BullSpacing.md,
              height: BullSpacing.md,
              child: checked
                  ? Icon(
                      Icons.check,
                      size: BullSpacing.md,
                      color: colors.primary,
                    )
                  : null,
            ),
            const Gap(BullSpacing.xs),
          ],
          if (item.leading case final leading?) ...[
            leading,
            const Gap(BullSpacing.xs),
          ],
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
                if (item.disabledReason ?? item.subtitle case final reason?)
                  Text(
                    reason,
                    style: context.bullType.caption.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
