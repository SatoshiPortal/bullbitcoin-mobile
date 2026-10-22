import 'package:bull_ui/src/feedback/bull_snack_bar.dart';
import 'package:bull_ui/src/layout/gap.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A read-only value with a copy button — the kit's take on
/// `core/widgets/inputs/copy_input.dart`, without its value modal.
///
/// The kit has no localisation, so [copiedMessage] (shown in a [BullSnackBar]
/// after a copy) comes translated from the caller. The copy button only
/// appears when there is something to copy.
class BullCopyField extends StatelessWidget {
  const BullCopyField({
    super.key,
    required this.text,
    required this.copiedMessage,
    this.clipboardText,
    this.maxLines,
    this.overflow,
  });

  /// The value shown.
  final String text;

  /// Toast shown once the value is on the clipboard.
  final String copiedMessage;

  /// What goes to the clipboard when it differs from [text].
  final String? clipboardText;

  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final toCopy = clipboardText ?? text;
    return Container(
      decoration: BoxDecoration(
        color: colors.onSecondary,
        borderRadius: BorderRadius.circular(BullRadius.sm),
        border: Border.all(color: colors.secondaryFixedDim),
      ),
      child: Row(
        children: [
          const Gap(15),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                text,
                style: context.bullText.bodyLarge?.copyWith(
                  color: colors.secondary,
                ),
                maxLines: maxLines,
                overflow: overflow,
              ),
            ),
          ),
          if (toCopy.isNotEmpty)
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              icon: Icon(Icons.copy_sharp, color: colors.secondary),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: toCopy));
                BullSnackBar.show(context, message: copiedMessage);
              },
            ),
          const Gap(8),
        ],
      ),
    );
  }
}
