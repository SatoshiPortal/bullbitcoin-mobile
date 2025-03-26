import 'package:bb_mobile/_ui/components/text/text.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:custom_sliding_segmented_control/custom_sliding_segmented_control.dart';
import 'package:flutter/cupertino.dart';

class BBSegmentFull extends StatefulWidget {
  const BBSegmentFull({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final Set<String> items;
  final String selected;
  final Function(String) onSelected;

  @override
  State<BBSegmentFull> createState() => _BBSegmentFullState();
}

class _BBSegmentFullState extends State<BBSegmentFull> {
  late final CustomSegmentedController<String> controller;

  @override
  void initState() {
    controller = CustomSegmentedController<String>();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (controller.value != widget.selected) {
      if (mounted) controller.value = widget.selected;
    }

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: CustomSlidingSegmentedControl<String>(
          controller: controller,
          initialValue: widget.selected,
          onValueChanged: (v) => widget.onSelected(v),
          innerPadding: const EdgeInsets.all(4),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInToLinear,
          // fromMax: true,
          isStretch: true,
          customSegmentSettings: CustomSegmentSettings(),
          decoration: BoxDecoration(
            color: context.colour.secondaryFixedDim,
            borderRadius: BorderRadius.circular(2),
          ),
          thumbDecoration: BoxDecoration(
            color: context.colour.onPrimary,
            borderRadius: BorderRadius.circular(2),
          ),

          children: {
            for (final item in widget.items)
              item: BBText(
                item,
                style: item == widget.selected
                    ? context.font.labelLarge
                    : context.font.labelMedium,
                color: item == widget.selected
                    ? context.colour.primary
                    : context.colour.outline,
              ),
          },
        ),
      ),
    );
  }
}
