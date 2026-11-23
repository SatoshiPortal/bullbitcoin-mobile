import '../buttons/bull_field_action.dart';
import '../data_display/bull_value_viewer.dart';

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
  }) : viewLabel = null,
       viewTitle = null;

  /// Shows a shortened value with named actions to view and copy it in full.
  const BullCopyField.withView({
    super.key,
    required this.text,
    required this.copiedMessage,
    required String this.viewLabel,
    required String this.viewTitle,
    this.copyLabel,
    this.clipboardText,
    this.label,
    this.backgroundColor,
  }) : onCopy = null,
       maxLines = 1,
       overflow = TextOverflow.ellipsis;

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

  final String? viewLabel;
  final String? viewTitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final toCopy = clipboardText ?? text;
    final heading = label;
    final title = viewTitle;
    final detailLabel = viewLabel;
    final copyName =
        copyLabel ?? MaterialLocalizations.of(context).copyButtonLabel;
    final valueText = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: context.bullType.body.copyWith(
          fontWeight: FontWeight.w500,
          color: colors.secondary,
        ),
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
    void showDetail() {
      if (title == null) return;
      BullValueViewer.showDetail(
        context,
        data: text,
        title: title,
        copyLabel: copyName,
        copiedMessage: copiedMessage,
        clipboardText: toCopy,
        additionalActions: (dialogContext) => [
          BullValueViewer.actionButton(
            icon: Icons.close,
            label: MaterialLocalizations.of(dialogContext).closeButtonLabel,
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      );
    }

    final value = Row(
      children: [
        const Gap(15),
        Expanded(
          child: title == null || text.isEmpty
              ? valueText
              : InkWell(
                  excludeFromSemantics: true,
                  onTap: showDetail,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: BullSpacing.xxl,
                    ),
                    child: valueText,
                  ),
                ),
        ),
        if (detailLabel != null && text.isNotEmpty) ...[
          BullFieldAction(
            label: detailLabel,
            icon: Icons.visibility_outlined,
            onPressed: showDetail,
          ),
          const Gap(BullSpacing.xxs),
        ],
        if (toCopy.isNotEmpty)
          BullFieldAction(
            label: copyName,
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
