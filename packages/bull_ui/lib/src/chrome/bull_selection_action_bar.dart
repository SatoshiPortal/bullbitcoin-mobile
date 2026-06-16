import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';

/// Sticky bottom bar with a summary line above a row of action buttons
/// (typically `BullToolButton`s). **New (key gap).** Generic slots — the
/// feature supplies the [summary] string and the [actions] widgets.
class BullSelectionActionBar extends StatelessWidget {
  const BullSelectionActionBar({
    super.key,
    required this.summary,
    required this.actions,
  });

  /// Summary line, e.g. "3 selected · total 0.001 BTC".
  final String summary;

  /// Action buttons laid out in an even row.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: colors.scrim,
            offset: const Offset(0, -4),
            blurRadius: 16,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                summary,
                style: BullTextStyles.bodyEmphasis.copyWith(color: colors.text),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: BullSpacing.s),
                    Expanded(child: actions[i]),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
