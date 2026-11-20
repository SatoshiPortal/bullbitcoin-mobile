import 'dart:math' as math;

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
    this.fitLabels = false,
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

  /// Grows the control to fit translated labels at the current text scale.
  final bool fitLabels;

  @override
  State<BullSegmented> createState() => _BullSegmentedState();
}

class _BullSegmentedState extends State<BullSegmented> {
  static const _innerPadding = 4.0;
  static const _segmentPadding = 12.0;

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
    Widget control(double height) => Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(context.bullShapes.button),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: CustomSlidingSegmentedControl<String>(
          height: height,
          initialValue: widget.initialValue ?? widget.items.first,
          onValueChanged: (v) {
            if (widget.disabledItems.contains(v)) return;
            setState(() => selectedSegment = v);
            widget.onSelected(v);
          },
          innerPadding: const EdgeInsets.all(_innerPadding),
          padding: _segmentPadding,
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
            color: dark ? colors.background : colors.surface,
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
    if (!widget.fitLabels) return control(widget.height);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth) return control(widget.height);
        final labelWidth = math.max(
          1.0,
          (constraints.maxWidth - 2 * _innerPadding) / widget.items.length -
              2 * _segmentPadding,
        );
        var height = widget.height;
        for (final label in widget.items) {
          for (final weight in [
            context.bullType.label.fontWeight,
            FontWeight.w400,
          ]) {
            final painter = TextPainter(
              text: TextSpan(
                text: label,
                style: context.bullType.label.copyWith(fontWeight: weight),
              ),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout(maxWidth: labelWidth);
            height = math.max(height, painter.height + 16);
            painter.dispose();
          }
        }
        return control(height);
      },
    );
  }
}
