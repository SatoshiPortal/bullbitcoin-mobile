import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:custom_sliding_segmented_control/custom_sliding_segmented_control.dart';
import 'package:flutter/material.dart';

/// Full-width sliding segmented control — duplicated from
/// `core/widgets/segment/segmented_full.dart`. Used for sort/filter segments.
class BullSegmented extends StatefulWidget {
  const BullSegmented({
    super.key,
    required this.items,
    this.initialValue,
    required this.onSelected,
    this.disabledItems = const {},
  }) : assert(items.length > 0, 'BullSegmented requires at least one item');

  /// The ordered set of segment labels.
  final Set<String> items;

  /// The initially selected label (defaults to the first item).
  final String? initialValue;

  /// Fired with the selected label.
  final ValueChanged<String> onSelected;

  /// Labels that cannot be selected.
  final Set<String> disabledItems;

  @override
  State<BullSegmented> createState() => _BullSegmentedState();
}

class _BullSegmentedState extends State<BullSegmented> {
  late String selectedSegment;

  @override
  void initState() {
    super.initState();
    selectedSegment = widget.initialValue ?? widget.items.first;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BullRadius.xs),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: CustomSlidingSegmentedControl<String>(
          initialValue: widget.initialValue ?? widget.items.first,
          onValueChanged: (v) {
            if (widget.disabledItems.contains(v)) return;
            setState(() => selectedSegment = v);
            widget.onSelected(v);
          },
          innerPadding: const EdgeInsets.all(4),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInToLinear,
          isStretch: true,
          customSegmentSettings: CustomSegmentSettings(),
          decoration: BoxDecoration(
            color: colors.textMuted.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(BullRadius.xs),
          ),
          thumbDecoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(BullRadius.xs),
          ),
          children: {
            for (final item in widget.items)
              item: Text(
                item,
                style: item == selectedSegment
                    ? Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colors.primary,
                      )
                    : widget.disabledItems.contains(item)
                    ? Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.textMuted.withValues(alpha: 0.5),
                      )
                    : Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: colors.text),
              ),
          },
        ),
      ),
    );
  }
}
