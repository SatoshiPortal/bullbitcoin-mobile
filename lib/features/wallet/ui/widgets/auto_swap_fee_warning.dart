import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
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
        color: context.colour.surface,
        borderRadius: BorderRadius.circular(8),
        // ignore: deprecated_member_use
        border: Border.all(color: context.colour.error.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BBText(
            'Auto Swap Blocked',
            style: context.font.titleMedium,
            color: context.colour.error,
          ),
          const Gap(12),
          BBText(
            'Attempting to swap $swapAmountBtc BTC. Current fee is $currentSwapFeePercent% of the swap amount and the fee threshold is set to ${autoSwapSettings.feeThresholdPercent}%',
            style: context.font.bodyMedium,
          ),
          const Gap(12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              BBButton.small(
                label: 'Block',
                onPressed: () {
                  context.read<WalletBloc>().add(
                    const BlockAutoSwapUntilNextExecution(),
                  );
                },
                bgColor: context.colour.error,
                textColor: context.colour.onSecondary,
                height: 32,
                width: 80,
                textStyle: context.font.bodyMedium,
              ),
              const Gap(16),
              BBButton.small(
                label: 'Allow',
                onPressed: () {
                  context.read<WalletBloc>().add(
                    const ExecuteAutoSwapFeeOverride(),
                  );
                },
                bgColor: context.colour.secondary,
                textColor: context.colour.onSecondary,
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
