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
/// [amount] in the observed fiat currency, or null while the price is
/// unknown, amounts are hidden, or the value cannot be computed.
String? arkFiatText(BuildContext context, Sats amount, BitcoinPrice? price) {
  if (price == null || !arkAmountsVisible(context)) return null;
  final value = price.fiatValueOf(amount.value);
  if (!value.isFinite) return null;
  final formatted = NumberFormat(
    '#,##0.00',
    Localizations.localeOf(context).toString(),
  ).format(value);
  return context.loc.fiatAmount(formatted, price.currency.code);
}

class ArkFiatAmount extends StatelessWidget {
  final Sats amount;
  final BitcoinPrice? price;
  final Color? color;

  /// Renders the equivalent inside an outlined chip, as on a balance hero.
  final bool chip;

  /// Prefixes the equivalent with "~", as for an amount still being edited.
  final bool approximate;

  const ArkFiatAmount({
    super.key,
    required this.amount,
    required this.price,
    this.color,
    this.chip = false,
    this.approximate = false,
  });

  @override
  Widget build(BuildContext context) {
    final fiat = arkFiatText(context, amount, price);
    if (fiat == null) return const SizedBox.shrink();
    final text = approximate ? context.loc.walletApproximateAmount(fiat) : fiat;
    final foreground = color ?? context.bull.textMuted;
    if (!chip) {
      return BullText(
        text,
        role: BullTextRole.label,
        color: foreground,
        textAlign: TextAlign.center,
      );
    }
    // Same pill as the fiat balance on the app's wallet cards.
    final fill = context.bull.border.withValues(alpha: 0.3);
    return BullBadge(
      label: text,
      background: fill,
      foreground: foreground,
      border: Border.all(color: fill),
      radius: context.bullShapes.button,
      textStyle: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );
  }
}
