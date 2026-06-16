import 'package:bull_ui/src/data_display/bull_text.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/widgets.dart';

/// Hero price display — duplicated from `core/widgets/cards/price_card.dart`.
///
/// Renders [text] as a large display number coloured for placement on a brand
/// surface (uses [BullTheme.onRed]).
class BullPriceCard extends StatelessWidget {
  const BullPriceCard({super.key, required this.text});

  /// The price string to display.
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return BullText(
      text,
      style: BullTextStyles.title.copyWith(
        fontSize: 43,
        fontWeight: FontWeight.w500,
      ),
      color: colors.onRed,
    );
  }
}
