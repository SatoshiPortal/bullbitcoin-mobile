import 'package:bb_mobile/core/themes/app_theme.dart';
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
            'Looking for balance and transactions…',
            style: context.font.bodyMedium?.copyWith(
              color: context.colour.secondary,
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          BBText(
            'Balance: ${bip84Status!.satoshis + liquidStatus!.satoshis}',
            style: context.font.bodyMedium?.copyWith(
              color: context.colour.secondary,
            ),
          ),
          const Gap(4),
          BBText(
            'Transactions: ${bip84Status!.transactions + liquidStatus!.transactions}',
            style: context.font.bodyMedium?.copyWith(
              color: context.colour.secondary,
            ),
          ),
        ],
      );
    }
  }
}
