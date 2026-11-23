import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/settings_failure_l10n.dart';
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
  int _revision = 0;

  Future<void> _select(bool fiat) async {
    if (_writing) return;
    setState(() => _writing = true);
    final result = await context.read<SettingsCubit>().setStartAmountsInFiat(
      fiat,
    );
    if (!mounted) return;
    setState(() {
      _writing = false;
      if (result case Err()) _revision++;
    });
    if (result case Err(:final failure)) {
      BullSnackBar.show(context, message: failure.toTranslated(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsCubit>().state.storedSettings;
    if (settings == null) return const SizedBox.shrink();
    final bitcoin = context.loc.amountInputBitcoin;
    final currency = settings.currencyCode;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BullSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: BullSpacing.xs),
            child: Text(
              context.loc.amountInputTitle,
              style: context.bullType.body,
            ),
          ),
          const Gap(BullSpacing.xs),
          Semantics(
            label: context.loc.amountInputTitle,
            enabled: !_writing,
            child: IgnorePointer(
              ignoring: _writing,
              child: BullSegmented(
                key: ValueKey(_revision),
                height: BullSpacing.xxl,
                items: {bitcoin, currency},
                initialValue: settings.startAmountsInFiat ? currency : bitcoin,
                onSelected: (selected) => _select(selected == currency),
              ),
            ),
          ),
          const Gap(BullSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: BullSpacing.xs),
            child: Text(
              context.loc.amountInputSettingsHint,
              style: context.bullType.label.copyWith(
                color: context.bull.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
