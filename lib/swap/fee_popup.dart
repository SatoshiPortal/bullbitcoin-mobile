import 'package:bb_mobile/_ui/bottom_sheet.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/headers.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class FeePopUp extends StatelessWidget {
  const FeePopUp({
    super.key,
    required this.lockupFees,
    required this.claimFees,
    required this.boltzFees,
  });

  final int lockupFees;
  final int claimFees;
  final int boltzFees;

  static Future openPopup(
    BuildContext context,
    int lockupFees,
    int claimFees,
    int boltzFees,
  ) {
    return showBBBottomSheet(
      context: context,
      child: FeePopUp(
        lockupFees: lockupFees,
        claimFees: claimFees,
        boltzFees: boltzFees,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // const Gap(32),
          const BBHeader.popUpCenteredText(
            text: 'Swap Fees breakdown',
            isLeft: true,
          ),

          const BBText.title(
            'Send network fee',
          ),
          const Gap(4),
          BBText.bodyBold('${lockupFees.toStringAsFixed(0)} sats'),
          const Gap(16),

          const BBText.title(
            'Claim network fee',
          ),
          const Gap(4),
          BBText.bodyBold('${claimFees.toStringAsFixed(0)} sats'),
          const Gap(16),

          const BBText.title(
            'Boltz service fee',
          ),
          const Gap(4),
          BBText.bodyBold('${boltzFees.toStringAsFixed(0)} sats'),
          const Gap(16),

          const BBText.title(
            'Total fees',
          ),
          const Gap(4),
          BBText.bodyBold(
            '${(lockupFees + claimFees + boltzFees).toStringAsFixed(0)} sats = $lockupFees + $claimFees + $boltzFees',
          ),
          const Gap(16),
        ],
      ),
    );
  }
}
