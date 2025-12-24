import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class InstructionsBottomSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<String> instructions;
  final VoidCallback? onClose;

  const InstructionsBottomSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.instructions,
    this.onClose,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    required List<String> instructions,
    VoidCallback? onClose,
  }) {
    return BlurredBottomSheet.show(
      context: context,
      child: InstructionsBottomSheet(
        title: title,
        subtitle: subtitle,
        instructions: instructions,
        onClose: onClose,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Column(
              children: [
                const Gap(20),
                // Title row with close button
                Row(
                  mainAxisAlignment: .spaceBetween,
                  children: [
                    const Gap(24),
                    Expanded(
                      child: BBText(
                        title,
                        style: context.font.headlineMedium,
                        textAlign: .center,
                      ),
                    ),
                    GestureDetector(
                      onTap: onClose ?? () => Navigator.of(context).pop(),
                      child: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  const Gap(16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: BBText(
                      subtitle!,
                      style: context.font.bodyMedium?.copyWith(
                        color: context.appColors.text,
                      ),
                      textAlign: .left,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: .start,
                  children: instructions
                      .asMap()
                      .entries
                      .map(
                        (entry) => _buildInstructionStep(
                          '${entry.key + 1}. ${entry.value}',
                          context,
                        ),
                      )
                      .toList(),
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
