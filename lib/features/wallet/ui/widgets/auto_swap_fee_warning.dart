import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class AutoSwapFeeWarning extends StatelessWidget {
  const AutoSwapFeeWarning({super.key});

  @override
  Widget build(BuildContext context) {
    final autoSwapFeeLimitExceeded = context.select(
      (WalletBloc bloc) => bloc.state.autoSwapFeeLimitExceeded,
    );
    final currentSwapFeePercent = context.select(
      (WalletBloc bloc) => bloc.state.currentSwapFeePercent,
    );
    final autoSwapSettings = context.select(
      (WalletBloc bloc) => bloc.state.autoSwapSettings,
    );
    final liquidWallet = context.select(
      (WalletBloc bloc) => bloc.state.defaultLiquidWallet(),
    );

    if (!autoSwapFeeLimitExceeded ||
        currentSwapFeePercent == null ||
        autoSwapSettings == null ||
        liquidWallet == null ||
        autoSwapSettings.alwaysBlock ||
        autoSwapSettings.blockTillNextExecution) {
      return const SizedBox.shrink();
    }

    final swapAmount = autoSwapSettings.swapAmount(
      liquidWallet.balanceSat.toInt(),
    );
    final swapAmountBtc = ConvertAmount.satsToBtc(
      swapAmount,
    ).toStringAsFixed(8);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(8),
        // ignore: deprecated_member_use
        border: Border.all(color: context.appColors.error.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          BBText(
            context.loc.walletAutoTransferBlockedTitle,
            style: context.font.titleMedium,
            color: context.appColors.error,
          ),
          const Gap(12),
          BBText(
            context.loc.walletAutoTransferBlockedMessage(
              swapAmountBtc,
              currentSwapFeePercent.toString(),
              autoSwapSettings.feeThresholdPercent.toString(),
            ),
            style: context.font.bodyMedium,
          ),
          const Gap(12),
          Row(
            mainAxisAlignment: .end,
            children: [
              BBButton.small(
                label: context.loc.walletAutoTransferBlockButton,
                onPressed: () {
                  context.read<WalletBloc>().add(
                    const BlockAutoSwapUntilNextExecution(),
                  );
                },
                bgColor: context.appColors.error,
                textColor: context.appColors.onSecondary,
                height: 32,
                width: 80,
                textStyle: context.font.bodyMedium,
              ),
              const Gap(16),
              BBButton.small(
                label: context.loc.walletAutoTransferAllowButton,
                onPressed: () {
                  context.read<WalletBloc>().add(
                    const ExecuteAutoSwapFeeOverride(),
                  );
                },
                bgColor: context.appColors.secondary,
                textColor: context.appColors.onSecondary,
                height: 32,
                width: 80,
                textStyle: context.font.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
