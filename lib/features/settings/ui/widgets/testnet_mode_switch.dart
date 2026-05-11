import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/widgets/warning_bottom_sheet.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TestnetModeSwitch extends StatelessWidget {
  const TestnetModeSwitch({super.key});

  Future<void> _showWarningBottomSheet(BuildContext context, bool enable) {
    return WarningBottomSheet.show(
      context,
      title: enable ? 'Switch to Testnet?' : 'Switch to Mainnet?',
      message: enable
          ? 'You are about to switch to Bitcoin Testnet. Your '
                'mainnet wallets will be hidden until you switch '
                'back. Some services may require restarting the '
                'app. Only proceed if you know what you are doing.'
          : 'Switching back to Bitcoin Mainnet. Your testnet '
                'wallets will be hidden until you switch back. '
                'Some services may require restarting the app.',
      confirmLabel: 'I understand',
      onConfirm: () =>
          context.read<SettingsCubit>().toggleTestnetMode(enable),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTestnetMode =
        context.watch<SettingsCubit>().state.environment == Environment.testnet;

    return Switch(
      value: isTestnetMode,
      onChanged: (value) => _showWarningBottomSheet(context, value),
    );
  }
}
