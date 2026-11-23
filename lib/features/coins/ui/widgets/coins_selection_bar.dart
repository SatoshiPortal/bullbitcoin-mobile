import 'package:bb_mobile/features/coins/presentation/coins_cubit.dart';
import 'package:primitives/primitives.dart'
    show BitcoinUnit, ConvertAmount, FormatAmount;
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Sticky bottom action bar shown in selection mode. Spending is available
/// only when every selected coin is spendable; mixed frozen/unfrozen
/// selections must be resolved first.
class CoinsSelectionBar extends StatelessWidget {
  const CoinsSelectionBar({
    super.key,
    required this.selectedCount,
    required this.selectedTotalSat,
    required this.anyUnfrozen,
    required this.anyFrozen,
    required this.onSend,
    required this.onSweep,
    required this.onFreeze,
    required this.onUnfreeze,
  });

  final int selectedCount;
  final BigInt selectedTotalSat;
  final bool anyUnfrozen;
  final bool anyFrozen;
  final VoidCallback onSend;
  final VoidCallback onSweep;
  final VoidCallback onFreeze;
  final VoidCallback onUnfreeze;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final bitcoinUnit =
        context.select((CoinsCubit c) => c.state.amountDisplay?.bitcoinUnit) ??
        BitcoinUnit.btc;
    final hideAmounts =
        context.select((CoinsCubit c) => c.state.amountDisplay?.hideAmounts) ??
        true;

    final total = hideAmounts
        ? '••••'
        : bitcoinUnit == BitcoinUnit.btc
        ? FormatAmount.btc(ConvertAmount.satsToBtc(selectedTotalSat.toInt()))
        : FormatAmount.sats(selectedTotalSat.toInt());
    final canSpend = anyUnfrozen && !anyFrozen;

    return BullSelectionActionBar(
      summary: '${loc.coinsSelectedCount(selectedCount)} · $total',
      actions: [
        if (canSpend)
          BullToolButton(
            label: loc.sendTitle,
            icon: BullIcons.arrowUpward,
            onPressed: onSend,
            primary: true,
          ),
        if (canSpend)
          BullToolButton(
            label: loc.coinsSweep,
            icon: BullIcons.callMerge,
            onPressed: onSweep,
          ),
        if (anyUnfrozen)
          BullToolButton(
            label: loc.coinsFreeze,
            icon: BullIcons.acUnit,
            onPressed: onFreeze,
          ),
        if (anyFrozen)
          BullToolButton(
            label: loc.coinsUnfreeze,
            icon: BullIcons.lockOpen,
            onPressed: onUnfreeze,
          ),
      ],
    );
  }
}
