import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

class SelectableListItem {
  final String? iconPath;
  final String title;
  final String subtitle1;
  final String subtitle2;
  final String value;

  /// When true, [subtitle2] is hidden and replaced with a shimmer line —
  /// used by fee preset tiles while the caller builds an unsigned PSBT
  /// to read the real fee. Prevents the row from displaying its own
  /// `rate × vsize` math while a real value is on the way.
  final bool isSubtitle2Loading;

  const SelectableListItem({
    this.iconPath,
    required this.title,
    required this.subtitle1,
    required this.subtitle2,
    required this.value,
    this.isSubtitle2Loading = false,
  });
}

class SelectableList extends StatelessWidget {
  const SelectableList({
    super.key,
    required this.items,
    required this.selectedValue,
  });

  final List<SelectableListItem> items;

  final String selectedValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        for (final item in items) ...[
          _SelectableRow(
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

class _SelectableRow extends StatelessWidget {
  const _SelectableRow({
    super.key,
    required this.item,
    required this.onSelected,
    required this.isSelected,
  });

  final SelectableListItem item;
  final Function() onSelected;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      radius: 2,
      onTap: onSelected,
      child: Material(
        elevation: isSelected ? 4 : 1,
        borderRadius: BorderRadius.circular(2),
        clipBehavior: .hardEdge,
        color: context.appColors.surface,
        shadowColor: context.appColors.border,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: .spaceBetween,
            crossAxisAlignment: .start,
            children: [
              if (item.iconPath != null)
                Image.asset(item.iconPath!, width: 24, height: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: .stretch,
                  children: [
                    BBText(item.title, style: context.font.headlineLarge),
                    const Gap(4),
                    BBText(item.subtitle1, style: context.font.labelMedium),
                    const Gap(2),
                    if (item.isSubtitle2Loading)
                      LoadingLineContent(
                        width: 160,
                        height: 12,
                        padding: EdgeInsets.zero,
                      )
                    else
                      BBText(item.subtitle2, style: context.font.labelMedium),
                  ],
                ),
              ),
              const Gap(8),
              Icon(
                Icons.radio_button_checked_outlined,
                color: isSelected
                    ? context.appColors.primary
                    : context.appColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
