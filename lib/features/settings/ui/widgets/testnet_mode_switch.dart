import 'package:bb_mobile/core_deprecated/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TestnetModeSwitch extends StatelessWidget {
  const TestnetModeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final isTestnetMode =
        context.watch<SettingsCubit>().state.environment == Environment.testnet;

    return Switch(
      value: isTestnetMode,
      onChanged: (value) {
        context.read<SettingsCubit>().toggleTestnetMode(value);
      },
    );
  }
}
