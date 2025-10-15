import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class DevModeSwitch extends StatelessWidget {
  const DevModeSwitch({super.key});

  Future<void> _showWarningDialog(BuildContext context) {
    return BlurredBottomSheet.show(
      context: context,
      child: Container(
        decoration: BoxDecoration(
          color: context.colour.onPrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Dev Mode', style: context.font.headlineMedium),
                const Gap(16),
                Text(
                  'This mode is risky. By enabling it, you acknowledge that you may lose money',
                  style: context.font.bodyMedium,
                ),
                const Gap(16),
                BBButton.big(
                  label: 'I understand',
                  onPressed: () {
                    context.read<SettingsCubit>().toggleDevMode(
                      true,
                      walletBloc: context.read<WalletBloc>(),
                    );
                    context.pop();
                  },
                  bgColor: context.colour.primary,
                  textColor: context.colour.onPrimary,
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
    final isDevModeEnabled =
        context.watch<SettingsCubit>().state.isDevModeEnabled ?? false;

    return Switch(
      value: isDevModeEnabled,
      onChanged: (value) async {
        if (value) {
          await _showWarningDialog(context);
        } else {
          await context.read<SettingsCubit>().toggleDevMode(
            false,
            walletBloc: context.read<WalletBloc>(),
          );
        }
      },
    );
  }
}
