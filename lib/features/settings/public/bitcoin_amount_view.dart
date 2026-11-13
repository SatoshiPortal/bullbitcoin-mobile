import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';

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
    this.interactive = true,
  });

  final int satsAmount;
  final TextStyle? style;
  final Color? color;
  final TextAlign? textAlign;
  final bool overrideHideAmounts;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final unit = context.select((SettingsCubit c) => c.state.bitcoinUnit);
    final hide = context.select(
      (SettingsCubit c) => c.state.hideAmounts ?? true,
    );
    if (unit == null) return const SizedBox.shrink();
    final masked = hide && !overrideHideAmounts;
    final satsText = masked ? '** sats' : FormatAmount.sats(satsAmount);
    final btcText = masked
        ? '** BTC'
        : FormatAmount.btc(ConvertAmount.satsToBtc(satsAmount));
    if (!interactive) {
      return Text(
        unit == BitcoinUnit.sats ? satsText : btcText,
        style: style?.copyWith(color: color),
        textAlign: textAlign,
      );
    }
    return BullAmount(
      satsText: satsText,
      btcText: btcText,
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
