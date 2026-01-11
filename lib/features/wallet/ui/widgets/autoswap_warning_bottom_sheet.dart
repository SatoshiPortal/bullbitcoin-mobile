import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class AutoSwapWarningBottomSheet extends StatelessWidget {
  const AutoSwapWarningBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return BlurredBottomSheet.show(
      context: context,
      child: const AutoSwapWarningBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final autoSwapSettings = context.select(
      (WalletBloc bloc) => bloc.state.autoSwapSettings,
    );

    final bitcoinUnit = context.select(
      (SettingsCubit cubit) => cubit.state.bitcoinUnit ?? BitcoinUnit.btc,
    );

    final targetBalance = autoSwapSettings != null
        ? (bitcoinUnit == BitcoinUnit.btc
            ? FormatAmount.btc(ConvertAmount.satsToBtc(autoSwapSettings.balanceThresholdSats))
            : FormatAmount.sats(autoSwapSettings.balanceThresholdSats))
        : (bitcoinUnit == BitcoinUnit.btc ? '0.01 BTC' : '1,000,000 sats');

    final maxBalance = autoSwapSettings != null
        ? (bitcoinUnit == BitcoinUnit.btc
            ? FormatAmount.btc(ConvertAmount.satsToBtc(autoSwapSettings.triggerBalanceSats))
            : FormatAmount.sats(autoSwapSettings.triggerBalanceSats))
        : (bitcoinUnit == BitcoinUnit.btc ? '0.02 BTC' : '2,000,000 sats');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BBText(
            context.loc.autoswapInfoTitle,
            style: context.font.headlineMedium,
            color: context.appColors.onSurface,
          ),
          const Gap(12),
          BBText(
            context.loc.autoswapWarningDescription,
            style: context.font.bodyMedium,
            color: context.appColors.onSurface,
          ),
          const Gap(16),
          BBText(
            context.loc.autoswapWarningTitle,
            style: context.font.bodyLarge,
            color: context.appColors.onSurface,
          ),
          const Gap(8),
          BBText(
            'Target Balance $targetBalance',
            style: context.font.bodyMedium,
            color: context.appColors.onSurface,
          ),
          const Gap(4),
          BBText(
            'Maximum Balance of $maxBalance',
            style: context.font.bodyMedium,
            color: context.appColors.onSurface,
          ),
          const Gap(16),
          BBText(
            context.loc.autoswapWarningExplanation,
            style: context.font.bodyMedium,
            color: context.appColors.onSurface,
          ),
          const Gap(24),
          BBButton.big(
            label: context.loc.autoswapInfoDismissButton,
            onPressed: () {
              context.read<WalletBloc>().add(const DismissAutoSwapWarning());
              Navigator.of(context).pop();
            },
            bgColor: context.appColors.onSurface,
            textColor: context.appColors.surface,
          ),
          const Gap(12),
          BBButton.big(
            label: context.loc.autoswapInfoSettingsButton,
            onPressed: () {
              Navigator.of(context).pop();
              context.pushNamed(SettingsRoute.autoswapSettings.name);
            },
            bgColor: context.appColors.surface,
            textColor: context.appColors.onSurface,
            outlined: true,
          ),
          const Gap(16),
          Center(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: BBText(
                context.loc.autoswapInfoRemindLater,
                style: context.font.bodyMedium?.copyWith(
                  decoration: TextDecoration.underline,
                ),
                color: context.appColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
