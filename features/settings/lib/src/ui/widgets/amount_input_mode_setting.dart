import 'package:settings/src/l10n.dart';
import 'package:settings/src/presentation/bloc/settings_cubit.dart';
import 'package:settings/src/presentation/settings_failure_l10n.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

class AmountInputModeSetting extends StatefulWidget {
  const AmountInputModeSetting({super.key});

  @override
  State<AmountInputModeSetting> createState() => _AmountInputModeSettingState();
}

class _AmountInputModeSettingState extends State<AmountInputModeSetting> {
  bool _writing = false;

  Future<void> _select(bool fiat) async {
    if (_writing) return;
    setState(() => _writing = true);
    final result = await context.read<SettingsCubit>().setStartAmountsInFiat(
      fiat,
    );
    if (!mounted) return;
    setState(() => _writing = false);
    if (result case Err(:final failure)) {
      BullSnackBar.show(context, message: failure.toTranslated(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsCubit>().state.storedSettings;
    if (settings == null) return const SizedBox.shrink();
    return BullSettingsEntryItem(
      icon: BullIcons.payments,
      title: context.loc.amountInputTitle,
      trailing: IgnorePointer(
        ignoring: _writing,
        child: BullPickerChip<bool>(
          tooltip: context.loc.amountInputTitle,
          value: settings.startAmountsInFiat,
          items: [
            BullPickerItem(value: false, label: context.loc.amountInputBitcoin),
            BullPickerItem(value: true, label: settings.currencyCode),
          ],
          onChanged: (fiat) {
            if (fiat == settings.startAmountsInFiat) return;
            _select(fiat);
          },
        ),
      ),
    );
  }
}
