import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Sticky bottom action bar shown in selection mode (§14). Summary line plus
/// Freeze / Unfreeze / Sweep tool buttons. Freeze is shown when any unfrozen
/// coin is selected; Unfreeze when any frozen coin is.
///
/// Sweep spends the selected coins entirely, so it is offered only when the
/// whole selection is spendable — [onSweep] is null otherwise (a frozen coin in
/// the selection, or a wallet whose network the sweep flow doesn't build for).
class CoinsSelectionBar extends StatelessWidget {
  const CoinsSelectionBar({
    super.key,
    required this.selectedCount,
    required this.selectedTotalSat,
    required this.anyUnfrozen,
    required this.anyFrozen,
    required this.onFreeze,
    required this.onUnfreeze,
    this.onSweep,
  });

  final int selectedCount;
  final BigInt selectedTotalSat;
  final bool anyUnfrozen;
  final bool anyFrozen;
  final VoidCallback onFreeze;
  final VoidCallback onUnfreeze;

  /// Null when the selection is frozen, non-Bitcoin, or cannot sign locally.
  final VoidCallback? onSweep;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final bitcoinUnit =
        context.select((SettingsCubit c) => c.state.bitcoinUnit) ??
        BitcoinUnit.btc;
    final hideAmounts =
        context.select((SettingsCubit c) => c.state.hideAmounts) ?? true;

    final total = hideAmounts
        ? '••••'
        : bitcoinUnit == BitcoinUnit.btc
        ? FormatAmount.btc(ConvertAmount.satsToBtc(selectedTotalSat.toInt()))
        : FormatAmount.sats(selectedTotalSat.toInt());

    final onSweep = this.onSweep;

    return BullSelectionActionBar(
      summary: '${loc.coinsSelectedCount(selectedCount)} · $total',
      actions: [
        if (onSweep != null)
          BullToolButton(
            label: loc.coinsSweep,
            icon: BullIcons.callMerge,
            onPressed: onSweep,
            primary: true,
          ),
        if (anyUnfrozen)
          BullToolButton(
            label: loc.coinsFreeze,
            icon: BullIcons.acUnit,
            onPressed: onFreeze,
            primary: onSweep == null,
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
