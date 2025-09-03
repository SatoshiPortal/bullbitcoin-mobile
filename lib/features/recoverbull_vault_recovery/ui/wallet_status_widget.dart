import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class WalletStatusWidget extends StatelessWidget {
  const WalletStatusWidget({super.key, required this.status});

  final ({BigInt satoshis, int transactions})? status;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (status != null) ...[
          BBText(
            'Balance: ${status?.satoshis.toString() ?? '0'}',
            style: context.font.bodyMedium?.copyWith(
              color: context.colour.secondary,
            ),
          ),
          const Gap(4),
          BBText(
            'Transactions: ${status?.transactions.toString() ?? '0'}',
            style: context.font.bodyMedium?.copyWith(
              color: context.colour.secondary,
            ),
          ),
        ] else ...[
          BBText(
            'Looking for balance and transactions…',
            style: context.font.bodyMedium?.copyWith(
              color: context.colour.secondary,
            ),
          ),
        ],
      ],
    );
  }
}
