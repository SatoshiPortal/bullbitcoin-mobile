import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class WalletStatusWidget extends StatelessWidget {
  const WalletStatusWidget({
    super.key,
    required this.bip84Status,
    required this.liquidStatus,
  });

  final ({BigInt satoshis, int transactions})? bip84Status;
  final ({BigInt satoshis, int transactions})? liquidStatus;

  @override
  Widget build(BuildContext context) {
    if (bip84Status == null || liquidStatus == null) {
      return Column(
        children: [
          BBText(
            context.loc.recoverbullLookingForBalance,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.onSurface,
            ),
          ),
        ],
      );
    } else {
      final totalBalance =
          (bip84Status!.satoshis + liquidStatus!.satoshis).toString();
      final totalTransactions =
          bip84Status!.transactions + liquidStatus!.transactions;

      return Column(
        children: [
          BBText(
            context.loc.recoverbullBalance(totalBalance),
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.onSurface,
            ),
          ),
          const Gap(4),
          BBText(
            context.loc.recoverbullTransactions(totalTransactions),
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.onSurface,
            ),
          ),
        ],
      );
    }
  }
}
