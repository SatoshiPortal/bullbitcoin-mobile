import 'package:bb_mobile/core_deprecated/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SatsBitcoinUnitSwitch extends StatelessWidget {
  const SatsBitcoinUnitSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final isSats =
        context.watch<SettingsCubit>().state.bitcoinUnit == BitcoinUnit.sats;

    return Switch(
      value: isSats,
      onChanged: (value) {
        context.read<SettingsCubit>().toggleSatsUnit(value);
      },
    );
  }
}
