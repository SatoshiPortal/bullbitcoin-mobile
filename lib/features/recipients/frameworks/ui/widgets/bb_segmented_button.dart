import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:custom_sliding_segmented_control/custom_sliding_segmented_control.dart';
import 'package:flutter/material.dart';

// TODO: This should be moved to the shared widgets package and replace the
// BBSegmentFull widget there, which is unneccessarily Stateful which causes
// various problems that need hacks to work around.
class BBSegmentedButton extends StatelessWidget {
  const BBSegmentedButton({
    super.key,
    required this.items,
    this.labels,
    required this.selected,
    required this.onChanged,
    this.disabledItems = const {},
  });

  final Set<String> items;
  final Map<String, String>? labels;
  final String selected;
  final Function(String) onChanged;
  final Set<String> disabledItems;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          clipBehavior: .antiAliasWithSaveLayer,
          child: CustomSlidingSegmentedControl<String>(
            controller: CustomSegmentedController(value: selected),
            initialValue: selected,
            onValueChanged: (v) {
              if (disabledItems.contains(v)) {
                return; // Don't allow selection of disabled items
              }

              onChanged(v);
            },
            innerPadding: const EdgeInsets.all(4),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInToLinear,
            // fromMax: true,
            isStretch: true,
            decoration: BoxDecoration(
              color: context.appColors.outline.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
            thumbDecoration: BoxDecoration(
              color: context.appColors.onPrimary,
              borderRadius: BorderRadius.circular(2),
            ),
            children: {
              for (final item in items)
                item: Text(
                  labels?[item] ?? item,
                  style:
                      item == selected
                          ? context.font.labelLarge?.copyWith(
                            color: context.appColors.primary,
                          )
                          : disabledItems.contains(item)
                          ? context.font.labelMedium?.copyWith(
                            color: context.appColors.outline.withValues(
                              alpha: 0.5,
                            ),
                          )
                          : context.font.labelMedium?.copyWith(
                            color: context.appColors.outline,
                          ),
                ),
            },
          ),
        ),
      ),
    );
  }
}
