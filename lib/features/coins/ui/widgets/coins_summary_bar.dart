import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The two-stat summary bar at the top of the Coins list (§14):
/// left = total coins count + total amount; right = frozen amount + spendable.
/// The frozen stat turns info-blue when any coin is frozen.
class CoinsSummaryBar extends StatelessWidget {
  const CoinsSummaryBar({
    super.key,
    required this.coinsCount,
    required this.totalSat,
    required this.frozenSat,
    required this.spendableSat,
    required this.hasFrozen,
  });

  final int coinsCount;
  final BigInt totalSat;
  final BigInt frozenSat;
  final BigInt spendableSat;
  final bool hasFrozen;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final bitcoinUnit =
        context.select((SettingsCubit c) => c.state.bitcoinUnit) ??
        BitcoinUnit.btc;
    final hideAmounts =
        context.select((SettingsCubit c) => c.state.hideAmounts) ?? true;

    String fmt(BigInt sat) {
      if (hideAmounts) return '••••';
      return bitcoinUnit == BitcoinUnit.btc
          ? FormatAmount.btc(ConvertAmount.satsToBtc(sat.toInt()))
          : FormatAmount.sats(sat.toInt());
    }

    final totalFiat = context.select(
      (BitcoinPriceBloc b) => b.state.calculateFiatPrice(totalSat.toInt()),
    );

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: BullStatTile(
              label: context.loc.coinsSummaryCoinsCount(coinsCount),
              value: fmt(totalSat),
              sub: (!hideAmounts && totalFiat != null) ? totalFiat : null,
            ),
          ),
          Container(
            width: 1,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: colors.outlineVariant,
          ),
          Expanded(
            child: BullStatTile(
              label: context.loc.coinsFrozen,
              value: hasFrozen ? fmt(frozenSat) : '—',
              sub: hasFrozen
                  ? '${fmt(spendableSat)} ${context.loc.coinsSpendable.toLowerCase()}'
                  : context.loc.coinsNoneFrozen,
              accent: hasFrozen ? colors.info : null,
            ),
          ),
        ],
      ),
    );
  }
}
