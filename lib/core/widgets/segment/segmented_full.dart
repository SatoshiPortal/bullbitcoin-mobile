import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:custom_sliding_segmented_control/custom_sliding_segmented_control.dart';
import 'package:flutter/cupertino.dart';

class BBSegmentFull extends StatefulWidget {
  const BBSegmentFull({
    super.key,
    required this.items,
    this.initialValue,
    required this.onSelected,
    this.disabledItems = const {},
  });

  final Set<String> items;
  final String? initialValue;
  final Function(String) onSelected;
  final Set<String> disabledItems;

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
        clipBehavior: .antiAliasWithSaveLayer,
        child: CustomSlidingSegmentedControl<String>(
          initialValue: widget.initialValue ?? widget.items.first,
          onValueChanged: (v) {
            if (widget.disabledItems.contains(v)) {
              return; // Don't allow selection of disabled items
            }
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
            color: context.appColors.textMuted.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(2),
          ),
          thumbDecoration: BoxDecoration(
            color: context.appColors.surface,
            borderRadius: BorderRadius.circular(2),
          ),
          children: {
            for (final item in widget.items)
              item: Text(
                item,
                style:
                    item == selectedSegment
                        ? context.font.labelLarge?.copyWith(
                          color: context.appColors.primary,
                        )
                        : widget.disabledItems.contains(item)
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
    );
  }
}
