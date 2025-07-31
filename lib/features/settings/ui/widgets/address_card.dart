import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';
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
  });

  final bool isUsed;
  final String address;
  final int index;
  final int balanceSat;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isUsed ? 'Used' : 'Unused',
              style: context.font.bodyMedium?.copyWith(
                color: context.colour.secondary,
              ),
            ),
            const Gap(8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: address));
                final theme = Theme.of(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Address copied to clipboard',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.white),
                    ),
                    duration: const Duration(seconds: 2),
                    backgroundColor: theme.colorScheme.onSurface.withAlpha(204),
                    behavior: SnackBarBehavior.floating,
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
                  color: context.colour.primary,
                ),
              ),
            ),
            const Gap(8),
            Text(
              'Index: $index',
              style: context.font.bodyMedium?.copyWith(
                color: context.colour.secondary,
              ),
            ),
            const Gap(8),
            Row(
              children: [
                Text(
                  'Balance: ',
                  style: context.font.bodyMedium?.copyWith(
                    color: context.colour.secondary,
                  ),
                ),
                CurrencyText(
                  balanceSat,
                  style: context.font.bodyMedium?.copyWith(
                    color: context.colour.secondary,
                  ),
                  showFiat: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
