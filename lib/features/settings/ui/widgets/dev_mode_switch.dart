import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:bb_mobile/core_deprecated/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core_deprecated/widgets/buttons/button.dart';
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
          color: context.appColors.onPrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: .min,
              children: [
                Text(
                  context.loc.settingsDevModeWarningTitle,
                  style: context.font.headlineMedium,
                ),
                const Gap(16),
                Text(
                  context.loc.settingsDevModeWarningMessage,
                  style: context.font.bodyMedium,
                ),
                const Gap(16),
                BBButton.big(
                  label: context.loc.settingsDevModeUnderstandButton,
                  onPressed: () {
                    context.read<SettingsCubit>().toggleDevMode(
                      true,
                      walletBloc: context.read<WalletBloc>(),
                    );
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
