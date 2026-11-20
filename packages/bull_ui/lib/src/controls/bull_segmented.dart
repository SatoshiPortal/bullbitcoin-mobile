import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:custom_sliding_segmented_control/custom_sliding_segmented_control.dart';
import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:bull_ui/src/theme/bull_typography.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/bull_tokens.dart';

/// Full-width sliding segmented control.
class BullSegmented extends StatefulWidget {
  const BullSegmented({
    super.key,
    required this.items,
    this.initialValue,
    required this.onSelected,
    this.disabledItems = const {},
    this.height = BullSpacing.xl + BullSpacing.xs,
  }) : assert(items.length > 0, 'BullSegmented requires at least one item');

  /// The ordered set of segment labels.
  final Set<String> items;

  /// The initially selected label (defaults to the first item).
  final String? initialValue;

  /// Fired with the selected label.
  final ValueChanged<String> onSelected;

  /// Labels that cannot be selected.
  final Set<String> disabledItems;
  final double height;

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

  // The sliding control moves its thumb when initialValue changes, so the
  // label styling has to follow or the two disagree after a parent rebuild.
  @override
  void didUpdateWidget(covariant BullSegmented oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue ||
        !widget.items.contains(selectedSegment)) {
      selectedSegment = widget.initialValue ?? widget.items.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    // The selected thumb takes the page colour and the track sits a step
    // away from it, in both themes: light thumb on a grey track, black thumb
    // on a dark grey track.
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(context.bullShapes.button),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: CustomSlidingSegmentedControl<String>(
          height: widget.height,
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
            color: dark
                ? colors.surfaceContainer
                : colors.textMuted.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(context.bullShapes.button),
          ),
          thumbDecoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(context.bullShapes.button),
          ),
          children: {
            for (final item in widget.items)
              // One role for every segment, so a control reads at the same
              // size on every screen; the selection shows by colour and weight.
              item: Semantics(
                button: true,
                enabled: !widget.disabledItems.contains(item),
                selected: item == selectedSegment,
                inMutuallyExclusiveGroup: true,
                child: Text(
                  item,
                  style: item == selectedSegment
                      ? context.bullType.label.copyWith(color: colors.primary)
                      : widget.disabledItems.contains(item)
                      ? context.bullType.label.copyWith(
                          fontWeight: FontWeight.w400,
                          color: colors.outline.withValues(alpha: 0.5),
                        )
                      : context.bullType.label.copyWith(
                          fontWeight: FontWeight.w400,
                          color: colors.secondary,
                        ),
                ),
              ),
          },
        ),
      ),
    );
  }
}
