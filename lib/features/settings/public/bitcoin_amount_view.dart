import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Resolves the global default and privacy policy for a local UI amount.
/// This widget deliberately has no access to a preference writer.
class BitcoinAmountView extends StatelessWidget {
  const BitcoinAmountView(
    this.satsAmount, {
    super.key,
    this.style,
    this.color,
    this.textAlign,
    this.overrideHideAmounts = false,
  });

  final int satsAmount;
  final TextStyle? style;
  final Color? color;
  final TextAlign? textAlign;
  final bool overrideHideAmounts;

  @override
  Widget build(BuildContext context) {
    final unit = context.select((SettingsCubit c) => c.state.bitcoinUnit);
    final hide = context.select(
      (SettingsCubit c) => c.state.hideAmounts ?? true,
    );
    if (unit == null) return const SizedBox.shrink();
    final masked = hide && !overrideHideAmounts;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final sats = NumberFormat.decimalPattern(locale).format(satsAmount);
    final absolute = BigInt.from(satsAmount).abs();
    final scale = BigInt.from(100000000);
    final whole = absolute ~/ scale;
    var fraction = (absolute % scale).toString().padLeft(8, '0');
    if (absolute == BigInt.zero || absolute >= BigInt.from(10000000)) {
      fraction = fraction.replaceFirst(RegExp(r'0+$'), '');
    }
    final separator = NumberFormat.decimalPattern(locale).symbols.DECIMAL_SEP;
    final sign = satsAmount < 0
        ? NumberFormat.decimalPattern(locale).symbols.MINUS_SIGN
        : '';
    final btc = fraction.isEmpty
        ? '$sign$whole'
        : '$sign$whole$separator$fraction';
    return BullAmount(
      satsText: masked ? '** sats' : '$sats sats',
      btcText: masked ? '** BTC' : '$btc BTC',
      defaultUnit: unit == BitcoinUnit.sats
          ? BullAmountUnit.sats
          : BullAmountUnit.btc,
      switchToBtcLabel: context.loc.amountSwitchToBtc,
      switchToSatsLabel: context.loc.amountSwitchToSats,
      style: style,
      color: color,
      textAlign: textAlign,
    );
  }
}
