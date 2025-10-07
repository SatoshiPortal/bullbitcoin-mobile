import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/recoverbull_vault_recovery/presentation/state.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class WalletStatusWidget extends StatelessWidget {
  const WalletStatusWidget({super.key, required this.state});

  final RecoverBullVaultRecoveryState state;

  @override
  Widget build(BuildContext context) {
    if (state.isStillLoading) {
      return Column(
        children: [
          BBText(
            'Looking for balance and transactions…',
            style: context.font.bodyMedium?.copyWith(
              color: context.colour.onSurface,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        BBText(
          'Balance: ${state.totalBalance}',
          style: context.font.bodyMedium?.copyWith(
            color: context.colour.onSurface,
          ),
        ),
        const Gap(4),
        BBText(
          'Transactions: ${state.totalTransactions}',
          style: context.font.bodyMedium?.copyWith(
            color: context.colour.onSurface,
          ),
        ),
      ],
    );
  }
}
