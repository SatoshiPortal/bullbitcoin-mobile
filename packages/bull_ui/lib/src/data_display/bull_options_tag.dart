import 'package:bull_ui/src/data_display/bull_text.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/material.dart';

/// A small bordered tag with a drop shadow — duplicated from
/// `core/widgets/cards/tag_card.dart` (`OptionsTag`).
class BullOptionsTag extends StatelessWidget {
  const BullOptionsTag({super.key, required this.text});

  /// The tag label.
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(color: colors.border, offset: const Offset(0, 2)),
        ],
      ),
      child: BullText(text, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}
