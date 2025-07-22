import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:custom_sliding_segmented_control/custom_sliding_segmented_control.dart';
import 'package:flutter/cupertino.dart';

class BBSegmentFull extends StatefulWidget {
  const BBSegmentFull({
    super.key,
    required this.items,
    this.initialValue,
    required this.onSelected,
  });

  final Set<String> items;
  final String? initialValue;
  final Function(String) onSelected;

  @override
  State<BBSegmentFull> createState() => _BBSegmentFullState();
}

class _BBSegmentFullState extends State<BBSegmentFull> {
  late String selectedSegment;

  @override
  void initState() {
    selectedSegment = widget.initialValue ?? widget.items.first;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: CustomSlidingSegmentedControl<String>(
          initialValue: widget.initialValue ?? widget.items.first,
          onValueChanged: (v) {
            setState(() {
              selectedSegment = v;
            });
            widget.onSelected(v);
          },
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
                style:
                    item == selectedSegment
                        ? context.font.labelLarge
                        : context.font.labelMedium,
                color:
                    item == selectedSegment
                        ? context.colour.primary
                        : context.colour.outline,
              ),
          },
        ),
      ),
    );
  }
}
