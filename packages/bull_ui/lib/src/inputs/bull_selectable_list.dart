import 'package:bull_ui/src/data_display/bull_text.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// One row of a [BullSelectableList].
class BullSelectableListItem {
  const BullSelectableListItem({
    this.iconPath,
    required this.title,
    required this.subtitle1,
    required this.subtitle2,
    required this.value,
  });

  /// Optional leading asset path (resolved by the host app's asset bundle).
  final String? iconPath;

  /// Primary line.
  final String title;

  /// First subtitle line.
  final String subtitle1;

  /// Second subtitle line.
  final String subtitle2;

  /// The value returned via `Navigator.pop` when this row is tapped.
  final String value;
}

/// A vertical list of single-select cards — duplicated from
/// `core/widgets/dropdown/selectable_list.dart` (`SelectableList`).
///
/// Tapping a row pops the enclosing route with that row's
/// [BullSelectableListItem.value]; the row matching [selectedValue] is shown
/// elevated and with a filled radio glyph.
class BullSelectableList extends StatelessWidget {
  const BullSelectableList({
    super.key,
    required this.items,
    required this.selectedValue,
  });

  /// The rows to render.
  final List<BullSelectableListItem> items;

  /// The currently selected row's value.
  final String selectedValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items) ...[
          _BullSelectableRow(
            key: ValueKey(item.title),
            item: item,
            onSelected: () => Navigator.pop(context, item.value),
            isSelected: item.value == selectedValue,
          ),
          const Gap(16),
        ],
      ],
    );
  }
}

class _BullSelectableRow extends StatelessWidget {
  const _BullSelectableRow({
    super.key,
    required this.item,
    required this.onSelected,
    required this.isSelected,
  });

  final BullSelectableListItem item;
  final Function() onSelected;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return InkWell(
      radius: 2,
      onTap: onSelected,
      child: Material(
        elevation: isSelected ? 4 : 1,
        borderRadius: BorderRadius.circular(BullRadius.card),
        clipBehavior: Clip.hardEdge,
        color: colors.surface,
        shadowColor: colors.border,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.iconPath != null)
                Image.asset(item.iconPath!, width: 24, height: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BullText(
                      item.title,
                      style: BullTextStyles.title.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Gap(4),
                    BullText(item.subtitle1, style: BullTextStyles.label),
                    const Gap(2),
                    BullText(item.subtitle2, style: BullTextStyles.label),
                  ],
                ),
              ),
              const Gap(8),
              Icon(
                Icons.radio_button_checked_outlined,
                color: isSelected ? colors.red : colors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
