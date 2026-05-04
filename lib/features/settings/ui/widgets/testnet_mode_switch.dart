import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class TestnetModeSwitch extends StatelessWidget {
  const TestnetModeSwitch({super.key});

  Future<void> _showWarningDialog(BuildContext context, bool enable) {
    return BlurredBottomSheet.show(
      context: context,
      child: Container(
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  enable ? 'Switch to Testnet?' : 'Switch to Mainnet?',
                  style: context.font.headlineMedium?.copyWith(
                    color: context.appColors.onSurface,
                  ),
                ),
                const Gap(16),
                Text(
                  enable
                      ? 'You are about to switch to Bitcoin Testnet. Your '
                            'mainnet wallets will be hidden until you switch '
                            'back. Some services may require restarting the '
                            'app. Only proceed if you know what you are doing.'
                      : 'Switching back to Bitcoin Mainnet. Your testnet '
                            'wallets will be hidden until you switch back. '
                            'Some services may require restarting the app.',
                  style: context.font.bodyMedium?.copyWith(
                    color: context.appColors.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Gap(16),
                BBButton.big(
                  label: 'I understand',
                  onPressed: () {
                    context.read<SettingsCubit>().toggleTestnetMode(enable);
                    context.pop();
                  },
                  bgColor: context.appColors.primary,
                  textColor: context.appColors.onPrimary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTestnetMode =
        context.watch<SettingsCubit>().state.environment == Environment.testnet;

    return Switch(
      value: isTestnetMode,
      onChanged: (value) => _showWarningDialog(context, value),
    );
  }
}
