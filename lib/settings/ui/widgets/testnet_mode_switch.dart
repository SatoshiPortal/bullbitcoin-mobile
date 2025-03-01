import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TestnetModeSwitch extends StatelessWidget {
  const TestnetModeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final isTestnetMode = context.watch<SettingsCubit>().state?.environment ==
        Environment.testnet;

    return Switch(
      value: isTestnetMode,
      onChanged: (value) {
        context.read<SettingsCubit>().toggleTestnetMode(value);
      },
    );
  }
}
