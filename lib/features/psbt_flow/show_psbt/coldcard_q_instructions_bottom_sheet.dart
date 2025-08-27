import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ColdcardQInstructionsBottomSheet extends StatelessWidget {
  const ColdcardQInstructionsBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ColdcardQInstructionsBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: context.colour.onPrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Column(
              children: [
                const Gap(20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Gap(24),
                    BBText(
                      'Coldcard Q instructions',
                      style: context.font.headlineMedium,
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.close),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInstructionStep(
                      '1. Login to your Coldcard Q device',
                      context,
                    ),
                    _buildInstructionStep(
                      '2. Add a passphrase if you have one (optional)',
                      context,
                    ),
                    _buildInstructionStep(
                      '3. Select "Scan any QR code" option',
                      context,
                    ),
                    _buildInstructionStep(
                      '4. Scan the QR code shown in the Bull wallet',
                      context,
                    ),
                    _buildInstructionStep(
                      '5. If you have trouble scanning',
                      context,
                    ),
                    _buildInstructionStep(
                      '   - Increase screen brightness on your device',
                      context,
                    ),
                    _buildInstructionStep(
                      '   - Move the red laser up and down over QR code',
                      context,
                    ),
                    _buildInstructionStep(
                      '   - Try moving your device back a little bit',
                      context,
                    ),
                    _buildInstructionStep(
                      '6. Once the transaction is imported in your Coldcard, review the destination address and the amount.',
                      context,
                    ),
                    _buildInstructionStep(
                      '7. Click the buttons to sign the transaction on your Coldcard.',
                      context,
                    ),
                    _buildInstructionStep(
                      '8. The Coldcard Q will then show you its own QR code.',
                      context,
                    ),
                    _buildInstructionStep(
                      '9. Click "I\'m done" in the Bull Bitcoin wallet.',
                      context,
                    ),
                    _buildInstructionStep(
                      '10. The Bull Bitcoin wallet will ask you to scan the QR code on the Coldcard. Scan it.',
                      context,
                    ),
                    _buildInstructionStep(
                      '11. The transaction will be imported in the Bull Bitcoin wallet.',
                      context,
                    ),
                    _buildInstructionStep(
                      "12. It's now ready to broadcast! As soon as you click broadcast, the transaction will be published on the Bitcoin network and the funds will be sent.",
                      context,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String text, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BBText(text, style: context.font.bodyMedium, maxLines: 3),
    );
  }
}
