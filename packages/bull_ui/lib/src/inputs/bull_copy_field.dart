import '../buttons/bull_field_action.dart';

import 'package:bull_ui/src/theme/bull_typography.dart';
import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:bull_ui/src/feedback/bull_snack_bar.dart';
import 'package:bull_ui/src/layout/gap.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

/// A read-only value with an optional clipboard value override.
///
/// [copiedMessage] (shown in a [BullSnackBar] after a copy) comes translated
/// from the caller. The copy button is named by [copyLabel], or Material's
/// translated "Copy" when null, and only appears when there is something to
/// copy.
class BullCopyField extends StatelessWidget {
  const BullCopyField({
    super.key,
    required this.text,
    required this.copiedMessage,
    this.copyLabel,
    this.clipboardText,
    this.onCopy,
    this.maxLines,
    this.overflow,
    this.label,
    this.backgroundColor,
  });

  /// The value shown.
  final String text;

  /// Toast shown once the value is on the clipboard.
  final String copiedMessage;

  /// Accessible name and tooltip of the copy button; Material's translated
  /// "Copy" when null.
  final String? copyLabel;

  /// What goes to the clipboard when it differs from [text].
  final String? clipboardText;

  /// Optional owner of copying and confirmation, for values requiring a
  /// lifetime policy such as secret clipboard expiry.
  final VoidCallback? onCopy;

  final int? maxLines;
  final TextOverflow? overflow;

  /// Optional heading inside the field, above the public value.
  final String? label;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final toCopy = clipboardText ?? text;
    final heading = label;
    final value = Row(
      children: [
        const Gap(15),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              text,
              style: context.bullType.body
                  .copyWith(fontWeight: FontWeight.w500)
                  .copyWith(color: colors.secondary),
              maxLines: maxLines,
              overflow: overflow,
            ),
          ),
        ),
        if (toCopy.isNotEmpty)
          BullFieldAction(
            label:
                copyLabel ?? MaterialLocalizations.of(context).copyButtonLabel,
            icon: Icons.copy_sharp,
            onPressed:
                onCopy ??
                () {
                  Clipboard.setData(ClipboardData(text: toCopy));
                  BullSnackBar.show(context, message: copiedMessage);
                },
          ),
        const Gap(8),
      ],
    );
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.surface,
        borderRadius: BorderRadius.circular(context.bullShapes.input),
        border: Border.all(color: colors.border),
      ),
      child: heading == null
          ? value
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    BullSpacing.md,
                    BullSpacing.sm,
                    BullSpacing.md,
                    BullSpacing.zero,
                  ),
                  child: Text(
                    heading,
                    style: context.bullType.body.copyWith(
                      color: colors.secondary,
                    ),
                  ),
                ),
                value,
              ],
            ),
    );
  }
}
