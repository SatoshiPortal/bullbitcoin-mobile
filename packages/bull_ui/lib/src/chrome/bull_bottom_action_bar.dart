import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';

/// A themed, safe-area-aware action bar for one or two bottom actions.
///
/// Actions are horizontal when there is enough room and become full-width
/// stacked actions on narrow layouts or enlarged text, preventing labels from
/// being squeezed. The action widgets and their labels remain caller-owned.
class BullBottomActionBar extends StatelessWidget {
  const BullBottomActionBar({super.key, required this.actions})
    : assert(actions.length == 1 || actions.length == 2);

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final stack = constraints.maxWidth < 400 || textScale > 1.15;
          final content = stack
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _withGaps(Axis.vertical),
                )
              : Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: BullSpacing.sm),
                      Expanded(child: actions[i]),
                    ],
                  ],
                );
          return DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(top: BorderSide(color: colors.outlineVariant)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(BullSpacing.md),
              child: content,
            ),
          );
        },
      ),
    );
  }

  List<Widget> _withGaps(Axis axis) {
    final result = <Widget>[];
    for (var i = 0; i < actions.length; i++) {
      if (i > 0) {
        result.add(
          SizedBox(
            height: axis == Axis.vertical ? BullSpacing.sm : null,
            width: axis == Axis.horizontal ? BullSpacing.sm : null,
          ),
        );
      }
      result.add(actions[i]);
    }
    return result;
  }
}
