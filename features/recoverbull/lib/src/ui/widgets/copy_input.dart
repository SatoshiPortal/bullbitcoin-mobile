import 'dart:ui' show ImageFilter;

import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import '../../l10n/context_localizations.dart';
import 'bull_aliases.dart';
import 'with_bull_theme.dart';

/// Copy/reveal adapter retained because no Bull UI component owns secret copy
/// semantics. It never logs the value, and keeps both the displayed and the
/// revealed value out of the semantics tree, so accessibility services cannot
/// read it.
class CopyInput extends StatelessWidget {
  final String value;
  final bool canShowValueModal;
  final int? maxLines;
  final String? clipboardText;
  final TextOverflow? overflow;
  final String? modalTitle;
  final Object? modalContent;

  const CopyInput({
    super.key,
    String? value,
    String? text,
    this.canShowValueModal = false,
    this.maxLines,
    this.clipboardText,
    this.overflow,
    this.modalTitle,
    this.modalContent,
  }) : value = value ?? text ?? '';

  @override
  Widget build(BuildContext context) {
    final copyValue = clipboardText ?? value;
    final canCopy = copyValue.isNotEmpty;
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.onSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.secondaryFixedDim),
      ),
      child: Row(
        children: [
          const SizedBox(width: 15),
          Expanded(
            child: InkWell(
              onTap: canShowValueModal
                  ? () => _showModal(context, copyValue)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: value.isEmpty
                    ? Shimmer.fromColors(
                        baseColor: colors.shimmerBase,
                        highlightColor: colors.shimmerHighlight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          child: Container(
                            width: double.infinity,
                            height: 12,
                            color: colors.surface,
                          ),
                        ),
                      )
                    : ExcludeSemantics(
                        child: BBText(
                          value,
                          style: context.font.bodyLarge,
                          color: colors.secondary,
                          maxLines: maxLines,
                          overflow: overflow,
                        ),
                      ),
              ),
            ),
          ),
          if (canShowValueModal && value.isNotEmpty)
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              icon: Icon(Icons.visibility_outlined, color: colors.secondary),
              onPressed: () => _showModal(context, copyValue),
            ),
          if (canCopy)
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              tooltip: context.loc.copyDialogButton,
              icon: Icon(Icons.copy_sharp, color: colors.secondary),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: copyValue));
                if (context.mounted) {
                  BullSnackBar.show(
                    context,
                    message: context.loc.copyDialogCopied,
                  );
                }
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  void _showModal(BuildContext context, String copyValue) {
    showDialog<void>(
      context: context,
      barrierColor: context.appColors.surface.withAlpha(100),
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: AlertDialog(
          backgroundColor: context.appColors.surface,
          title: modalTitle == null
              ? null
              : Text(
                  modalTitle!,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
          content: SingleChildScrollView(
            child: ExcludeSemantics(
              child: SelectableText(
                (modalContent ?? value).toString(),
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontSize: 18),
              ),
            ),
          ),
          actions: [
            if (copyValue.isNotEmpty)
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: context.appColors.secondary,
                  textStyle: Theme.of(context).textTheme.bodyLarge,
                ),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: copyValue));
                  if (context.mounted) {
                    BullSnackBar.show(
                      context,
                      message: context.loc.copyDialogCopied,
                    );
                  }
                },
                child: Text(context.loc.copyDialogButton),
              ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: context.appColors.primary,
                textStyle: Theme.of(context).textTheme.bodyLarge,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.loc.closeDialogButton),
            ),
          ],
        ),
      ),
    );
  }
}
