import 'package:bull_ui/src/theme/bull_typography.dart';
import 'package:material_ui/material_ui.dart';

import '../../generated/l10n/bull_ui_localizations.dart';
import '../theme/bull_theme.dart';
import 'bull_amount_scope.dart';

/// The fiat value of a bitcoin amount, shown under it. [formatted] carries
/// its currency code last ("12.34 CAD"); without a price it is null and
/// nothing is shown. Hidden amounts hide it too, keeping the currency code.
class BullFiatEquivalent extends StatelessWidget {
  const BullFiatEquivalent(
    this.formatted, {
    super.key,
    this.textAlign = TextAlign.end,
    this.color,
    this.overrideHideAmounts = false,
  });

  final String? formatted;
  final TextAlign textAlign;
  final Color? color;

  /// Shows the value even while amounts are hidden, as [BullAmount] does.
  final bool overrideHideAmounts;

  @override
  Widget build(BuildContext context) {
    final value = formatted;
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    final snapshot = BullAmountScope.maybeOf(context)?.snapshot;
    final hidden =
        snapshot == null ||
        !snapshot.isReady ||
        (snapshot.hideAmounts && !overrideHideAmounts);
    final text = hidden
        ? '${BullUiLocalizations.of(context).amountHidden} '
              '${value.split(' ').last}'
        : '~$value';
    return Text(
      text,
      textAlign: textAlign,
      style: context.bullType.caption.copyWith(
        color: color ?? context.bull.textMuted,
      ),
    );
  }
}
