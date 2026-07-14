import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Install instructions shown after the firmware has been verified and exported: how to load the .dfu from microSD and confirm the upgrade on the device.
class ColdcardUpdateInstructionsBottomSheet extends StatelessWidget {
  const ColdcardUpdateInstructionsBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return BlurredBottomSheet.show(
      context: context,
      child: const ColdcardUpdateInstructionsBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loadSteps = [
      context.loc.coldcardUpdateInstructionsLoadStep1,
      context.loc.coldcardUpdateInstructionsLoadStep2,
      context.loc.coldcardUpdateInstructionsLoadStep3,
      context.loc.coldcardUpdateInstructionsLoadStep4,
      context.loc.coldcardUpdateInstructionsLoadStep5,
      context.loc.coldcardUpdateInstructionsLoadStep6,
    ];
    final confirmSteps = [
      context.loc.coldcardUpdateInstructionsConfirmStep1,
      context.loc.coldcardUpdateInstructionsConfirmStep2,
      context.loc.coldcardUpdateInstructionsConfirmStep3,
      context.loc.coldcardUpdateInstructionsConfirmStep4,
      context.loc.coldcardUpdateInstructionsConfirmStep5,
    ];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: .min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 10),
            child: Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                const Gap(24),
                Expanded(
                  child: BBText(
                    context.loc.coldcardUpdateInstructionsTitle,
                    style: context.font.headlineMedium,
                    textAlign: .center,
                    maxLines: 2,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    _SectionHeader(
                      title: context.loc.coldcardUpdateInstructionsLoadSection,
                    ),
                    const Gap(12),
                    for (final (index, step) in loadSteps.indexed)
                      _Step(number: index + 1, text: step),
                    const Gap(12),
                    _WarningBox(
                      paragraphs: [
                        context.loc.coldcardUpdateInstructionsRedLedNote,
                        context.loc.coldcardUpdateInstructionsPowerWarning,
                      ],
                    ),
                    const Gap(24),
                    _SectionHeader(
                      title:
                          context.loc.coldcardUpdateInstructionsConfirmSection,
                    ),
                    const Gap(12),
                    for (final (index, step) in confirmSteps.indexed)
                      _Step(number: index + 1, text: step),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return BBText(title, style: context.font.titleMedium, maxLines: 2);
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: .start,
        children: [
          BBText('$number.', style: context.font.bodyMedium),
          const Gap(8),
          Expanded(
            child: BBText(text, style: context.font.bodyMedium, maxLines: 5),
          ),
        ],
      ),
    );
  }
}

class _WarningBox extends StatelessWidget {
  const _WarningBox({required this.paragraphs});

  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: context.appColors.error),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Icon(Icons.warning_amber, color: context.appColors.error, size: 20),
          const Gap(8),
          for (final paragraph in paragraphs) ...[
            BBText(paragraph, style: context.font.bodySmall, maxLines: 8),
            if (paragraph != paragraphs.last) const Gap(8),
          ],
        ],
      ),
    );
  }
}
