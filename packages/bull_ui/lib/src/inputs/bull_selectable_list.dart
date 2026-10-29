import 'package:bull_ui/src/data_display/bull_text.dart';
import 'package:bull_ui/src/feedback/bull_shimmer.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/src/layout/gap.dart';

/// One row of a [BullSelectableList].
class BullSelectableListItem {
  const BullSelectableListItem({
    this.iconPath,
    required this.title,
    required this.subtitle1,
    required this.subtitle2,
    required this.value,
    this.isSubtitle2Loading = false,
  });

  /// Optional leading asset path (resolved by the host app's asset bundle).
  final String? iconPath;

  /// Primary line.
  final String title;

  /// First subtitle line.
  final String subtitle1;

  /// Second subtitle line.
  final String subtitle2;

  /// The value reported to `onChanged` or `Navigator.pop` when tapped.
  final String value;

  /// Renders a shimmering placeholder in place of [subtitle2] while the value
  /// it displays is still being fetched.
  final bool isSubtitle2Loading;
}

/// A vertical list of single-select cards.
///
/// Tapping a row reports its [BullSelectableListItem.value] to [onChanged], or pops the enclosing route when no callback is provided. The row matching [selectedValue] is shown elevated and with a filled radio glyph.
class BullSelectableList extends StatelessWidget {
  const BullSelectableList({
    super.key,
    required this.items,
    required this.selectedValue,
    this.onChanged,
  });

  /// The rows to render.
  final List<BullSelectableListItem> items;

  /// The currently selected row's value.
  final String selectedValue;

  /// Select in place when provided; otherwise preserve the picker pop behavior.
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items) ...[
          _BullSelectableRow(
            key: ValueKey(item.title),
            item: item,
            onSelected: () {
              final callback = onChanged;
              if (callback != null) {
                callback(item.value);
              } else {
                Navigator.pop(context, item.value);
              }
            },
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
    return Semantics(
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: InkWell(
        radius: 2,
        onTap: onSelected,
        child: Material(
          elevation: isSelected ? 4 : 1,
          borderRadius: BorderRadius.circular(BullRadius.xxs),
          clipBehavior: Clip.hardEdge,
          color: colors.surface,
          shadowColor: colors.border,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.iconPath case final iconPath?)
                  Image.asset(iconPath, width: 24, height: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BullText(
                        item.title,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const Gap(4),
                      BullText(
                        item.subtitle1,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const Gap(2),
                      if (item.isSubtitle2Loading)
                        const BullShimmerLine(
                          width: 160,
                          height: 12,
                          padding: EdgeInsets.zero,
                        )
                      else
                        BullText(
                          item.subtitle2,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                    ],
                  ),
                ),
                const Gap(8),
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_outlined
                      : Icons.radio_button_unchecked,
                  color: isSelected ? colors.primary : colors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
