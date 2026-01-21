import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';
import 'package:bb_mobile/core/widgets/labels_widget.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

class AddressCard extends StatelessWidget {
  const AddressCard({
    super.key,
    required this.isUsed,
    required this.address,
    required this.index,
    required this.balanceSat,
    required this.labels,
  });

  final bool isUsed;
  final String address;
  final int index;
  final int balanceSat;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: .start,
          mainAxisSize: .min,
          children: [
            Text(
              isUsed
                  ? context.loc.addressCardUsedLabel
                  : context.loc.addressCardUnusedLabel,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.onSurface,
              ),
            ),
            const Gap(8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: address));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.loc.addressCardCopiedMessage,
                      textAlign: .center,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.appColors.surface,
                      ),
                    ),
                    duration: const Duration(seconds: 2),
                    backgroundColor: context.appColors.onSurface.withAlpha(204),
                    behavior: .floating,
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              },
              child: Text(
                StringFormatting.truncateMiddle(address, head: 10, tail: 20),
                style: context.font.headlineMedium?.copyWith(
                  color: context.appColors.primary,
                ),
              ),
            ),
            const Gap(8),
            Text(
              '${context.loc.addressCardIndexLabel}$index',
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
            const Gap(8),
            Row(
              children: [
                Text(
                  context.loc.addressCardBalanceLabel,
                  style: context.font.bodyMedium?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
                CurrencyText(
                  balanceSat,
                  style: context.font.bodyMedium?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                  showFiat: false,
                ),
              ],
            ),
            if (labels.isNotEmpty) ...[
              const Gap(8),
              LabelsWidget(labels: labels, reference: address),
            ],
          ],
        ),
      ),
    );
  }
}
