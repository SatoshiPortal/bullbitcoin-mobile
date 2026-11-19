import 'package:bull_pricer/bull_pricer.dart' show BitcoinPrice;
import 'package:bull_ui/bull_ui.dart';
import 'package:intl/intl.dart';
import 'package:primitives/primitives.dart';

import '../presentation/ark_l10n.dart';

/// Locale-aware satoshi text, preserving the integer without floating conversion.
String formatArkSats(BuildContext context, Sats amount) {
  final separator = NumberFormat.decimalPattern(
    Localizations.localeOf(context).toString(),
  ).symbols.GROUP_SEP;
  final value = amount.value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => separator,
  );
  return context.loc.walletBalance(value);
}

bool arkAmountsVisible(BuildContext context) {
  final preferences = BullAmountScope.maybeOf(context)?.snapshot;
  return preferences != null && preferences.isReady && !preferences.hideAmounts;
}

/// Passive observations follow the app's amount privacy preference.
String formatArkObservedSats(
  BuildContext context,
  Sats? amount, {
  bool withUnit = true,
}) {
  if (!arkAmountsVisible(context)) return context.loc.hiddenAmount;
  if (amount == null) return context.loc.unknown;
  return withUnit ? formatArkSats(context, amount) : amount.value.toString();
}

/// A display equivalent from the host's network-scoped price observation.
class ArkFiatAmount extends StatelessWidget {
  final Sats amount;
  final BitcoinPrice? price;
  final Color? color;

  const ArkFiatAmount({
    super.key,
    required this.amount,
    required this.price,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final observed = price;
    if (observed == null || !arkAmountsVisible(context)) {
      return const SizedBox.shrink();
    }
    final value = observed.fiatValueOf(amount.value);
    if (!value.isFinite) return const SizedBox.shrink();
    final formatted = NumberFormat(
      '#,##0.00',
      Localizations.localeOf(context).toString(),
    ).format(value);
    return BullText(
      context.loc.fiatAmount(formatted, observed.currency.code),
      role: BullTextRole.label,
      color: color ?? context.bull.textMuted,
      textAlign: TextAlign.center,
    );
  }
}
