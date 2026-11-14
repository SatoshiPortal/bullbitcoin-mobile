import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TestnetModeSwitch extends StatelessWidget {
  const TestnetModeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsCubit>().state.storedSettings;
    if (settings == null ||
        settings.isSuperuser != true ||
        settings.isDevModeEnabled != true) {
      return const SizedBox.shrink();
    }
    return DropdownButton<Environment>(
      value: settings.environment,
      items: [
        DropdownMenuItem(
          value: Environment.mainnet,
          child: Text(context.loc.electrumMainnet),
        ),
        DropdownMenuItem(
          value: Environment.testnet,
          child: Text(context.loc.electrumTestnet),
        ),
        DropdownMenuItem(
          value: Environment.regtest,
          child: Text(context.loc.electrumRegtest),
        ),
      ],
      onChanged: (environment) {
        if (environment != null) {
          context.read<SettingsCubit>().selectNetwork(environment);
        }
      },
    );
  }
}
