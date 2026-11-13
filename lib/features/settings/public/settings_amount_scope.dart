import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Binds the shared amount UI to the existing application preference writer.
class SettingsAmountScope extends StatelessWidget {
  const SettingsAmountScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final unit = context.select((SettingsCubit c) => c.state.bitcoinUnit);
    if (unit == null) return child;
    return BullAmountPreferencesScope(
      preferences: BullAmountPreferences(
        defaultUnit: unit == BitcoinUnit.sats
            ? BullAmountUnit.sats
            : BullAmountUnit.btc,
        changeDefaultUnit: (target) async {
          final cubit = context.read<SettingsCubit>();
          final requested = target == BullAmountUnit.sats
              ? BitcoinUnit.sats
              : BitcoinUnit.btc;
          await cubit.toggleSatsUnit(requested == BitcoinUnit.sats);
          return cubit.state.bitcoinUnit == requested;
        },
        globalActionLabel: context.loc.amountChangeDefaultEverywhere,
        tooltip: context.loc.amountGesturesHint,
        satsEverywhereMessage: context.loc.amountsDisplayedEverywhereSats,
        btcEverywhereMessage: context.loc.amountsDisplayedEverywhereBtc,
        undoLabel: context.loc.amountUndo,
        failureMessage: context.loc.oopsSomethingWentWrong,
      ),
      child: child,
    );
  }
}
