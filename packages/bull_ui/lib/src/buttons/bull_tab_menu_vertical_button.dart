import 'package:bull_ui/src/data_display/bull_text.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/src/layout/gap.dart';

/// A bordered menu row with an optional leading icon and a title — duplicated
/// from `core/widgets/navbar/tab_menu_vertical_button.dart`
/// (`TabMenuVerticalButton`).
///
/// When [onTap] is null the row is dimmed (disabled).
class BullTabMenuVerticalButton extends StatelessWidget {
  const BullTabMenuVerticalButton({
    super.key,
    this.icon,
    required this.title,
    required this.onTap,
  });

  /// Optional leading icon widget.
  final Widget? icon;

  /// Row title.
  final String title;

  /// Tap callback; null renders the row disabled.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Container(
      decoration: BoxDecoration(
        color: onTap != null ? colors.surface : colors.border,
        borderRadius: BorderRadius.circular(2.76),
        border: Border.all(color: colors.border, width: 0.69),
        boxShadow: [
          BoxShadow(color: colors.border, offset: const Offset(0, 2)),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(2.76),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              ?icon,
              const Gap(8),
              BullText(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
