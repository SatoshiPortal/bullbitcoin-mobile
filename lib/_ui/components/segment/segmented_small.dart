import 'package:bb_mobile/_ui/components/text/text.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:custom_sliding_segmented_control/custom_sliding_segmented_control.dart';
import 'package:flutter/material.dart';

class SegmentedSmall extends StatelessWidget {
  const SegmentedSmall({
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
        borderRadius: BorderRadius.circular(4),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: CustomSlidingSegmentedControl<String>(
          onValueChanged: (v) => onSelected(v),
          decoration: BoxDecoration(
            color: context.colour.secondaryFixedDim,
            borderRadius: BorderRadius.circular(4),
          ),
          thumbDecoration: BoxDecoration(
            color: context.colour.primary,
            borderRadius: BorderRadius.circular(4),
          ),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInToLinear,
          children: {
            for (final item in items)
              item: SizedBox(
                height: 38 - 10,
                width: 28 - 10,
                child: Center(
                  child: BBText(
                    item,
                    style: context.font.bodyLarge,
                    color: item == selected
                        ? context.colour.onPrimary
                        : context.colour.secondary,
                  ),
                ),
              ),
          },
        ),
      ),
    );
  }
}
