import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bull_ui/bull_ui.dart' show BullText, Gap;
import 'package:flutter/material.dart';

class BitcoinPolicyCondition extends StatelessWidget {
  final BitcoinPolicyNode node;
  final String Function(BitcoinPolicyNode) describe;
  final Color textColor;

  const BitcoinPolicyCondition({
    super.key,
    required this.node,
    required this.describe,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 7),
        child: Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: context.appColors.textMuted,
            shape: BoxShape.circle,
          ),
        ),
      ),
      const Gap(10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BullText(
              describe(node),
              style: context.font.bodySmall,
              color: textColor,
            ),
            if (node case BitcoinThresholdPolicyNode(:final children)) ...[
              const Gap(8),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, child) in children.indexed) ...[
                      BitcoinPolicyCondition(
                        node: child,
                        describe: describe,
                        textColor: textColor,
                      ),
                      if (index != children.length - 1) const Gap(8),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}
