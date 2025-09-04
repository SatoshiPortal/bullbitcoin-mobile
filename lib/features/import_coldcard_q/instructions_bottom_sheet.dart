import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class InstructionsBottomSheet extends StatelessWidget {
  const InstructionsBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const InstructionsBottomSheet(),
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
                      '3. Select the advanced/settings menu',
                      context,
                    ),
                    _buildInstructionStep('4. Click "export wallet"', context),
                    _buildInstructionStep(
                      '5. Select "descriptor" as export type',
                      context,
                    ),
                    _buildInstructionStep(
                      '6. Press "Enter" on first screen',
                      context,
                    ),
                    _buildInstructionStep(
                      '7. Press "Enter" on second screen"',
                      context,
                    ),
                    _buildInstructionStep(
                      '8. Select your address type (use Segwit if unsure)',
                      context,
                    ),
                    _buildInstructionStep(
                      '9. Click the QR code button on the device. It will show you a QR code on the device.',
                      context,
                    ),
                    _buildInstructionStep(
                      '10. Click the "open camera" button',
                      context,
                    ),
                    _buildInstructionStep(
                      '11. Scan the QR code you see on your device.',
                      context,
                    ),
                    _buildInstructionStep("12. That's it!", context),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: BBText(text, style: context.font.bodyMedium, maxLines: 3),
    );
  }
}
