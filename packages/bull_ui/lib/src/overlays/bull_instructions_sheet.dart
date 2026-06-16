import 'package:bull_ui/src/data_display/bull_text.dart';
import 'package:bull_ui/src/overlays/bull_bottom_sheet.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// A bottom sheet that lists numbered instruction steps — duplicated from
/// `core/widgets/bottom_sheet/instructions_bottom_sheet.dart`
/// (`InstructionsBottomSheet`).
///
/// Shows a centered [title], an optional [subtitle] and a scrollable list of
/// auto-numbered [instructions]. Use [BullInstructionsSheet.show] to present it
/// through [BullBottomSheet].
class BullInstructionsSheet extends StatelessWidget {
  const BullInstructionsSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.instructions,
    this.onClose,
  });

  /// Sheet header title.
  final String title;

  /// Optional descriptive subtitle under the title.
  final String? subtitle;

  /// The instruction lines, rendered as a numbered list.
  final List<String> instructions;

  /// Invoked by the close icon; defaults to popping the sheet.
  final VoidCallback? onClose;

  /// Present the instructions sheet via [BullBottomSheet].
  static Future<void> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    required List<String> instructions,
    VoidCallback? onClose,
  }) {
    return BullBottomSheet.show(
      context: context,
      child: BullInstructionsSheet(
        title: title,
        subtitle: subtitle,
        instructions: instructions,
        onClose: onClose,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
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
                // Title row with close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Gap(24),
                    Expanded(
                      child: BullText(
                        title,
                        style: BullTextStyles.title,
                        textAlign: TextAlign.center,
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
                    child: BullText(
                      subtitle!,
                      style: BullTextStyles.body,
                      color: colors.text,
                      textAlign: TextAlign.left,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: instructions
                      .asMap()
                      .entries
                      .map(
                        (entry) => _buildInstructionStep(
                          '${entry.key + 1}. ${entry.value}',
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

  Widget _buildInstructionStep(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BullText(text, style: BullTextStyles.body, maxLines: 3),
    );
  }
}
