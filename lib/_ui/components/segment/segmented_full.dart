import 'package:bb_mobile/_ui/components/text/text.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:custom_sliding_segmented_control/custom_sliding_segmented_control.dart';
import 'package:flutter/cupertino.dart';

class BBSwitcher<T extends Object> extends StatelessWidget {
  const BBSwitcher({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final Set<String> items;
  final String selected;
  final Function(String) onSelected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: CustomSlidingSegmentedControl<String>(
          onValueChanged: (v) => onSelected(v),
          innerPadding: const EdgeInsets.all(4),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInToLinear,
          // fromMax: true,
          isStretch: true,
          decoration: BoxDecoration(
            color: context.colour.secondaryFixedDim,
            borderRadius: BorderRadius.circular(2),
          ),
          thumbDecoration: BoxDecoration(
            color: context.colour.onPrimary,
            borderRadius: BorderRadius.circular(2),
          ),
          children: {
            for (final item in items)
              item: BBText(
                item,
                style: item == selected
                    ? context.font.labelLarge
                    : context.font.labelMedium,
                color: item == selected
                    ? context.colour.primary
                    : context.colour.outline,
              ),
          },
        ),
      ),
    );
  }
}
