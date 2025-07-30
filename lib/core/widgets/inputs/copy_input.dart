import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

class CopyInput extends StatelessWidget {
  const CopyInput({
    super.key,
    required this.text,
    this.clipboardText,
    this.maxLines,
    this.overflow,
    this.canShowValueModal = false,
    this.modalTitle,
    this.modalContent,
  });

  final String text;
  // In case it should be different from the shown text
  final String? clipboardText;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool canShowValueModal;
  final String? modalTitle;
  // In case it should be different from the shown text
  final String? modalContent;

  @override
  Widget build(BuildContext context) {
    final isValueLoading = text.isEmpty;
    final canCopy =
        (clipboardText == null && text.isNotEmpty) ||
        (clipboardText != null && clipboardText!.isNotEmpty);

    return Container(
      decoration: BoxDecoration(
        color: context.colour.onPrimary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colour.secondaryFixedDim),
      ),
      child: Row(
        children: [
          const Gap(15),
          Expanded(
            child: InkWell(
              onTap:
                  canShowValueModal
                      ? () {
                        _onShowValueModal(context, canCopy: canCopy);
                      }
                      : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child:
                    isValueLoading
                        ? const LoadingLineContent()
                        : BBText(
                          text,
                          style: context.font.bodyLarge,
                          color: context.colour.secondary,
                          maxLines: maxLines,
                          overflow: overflow,
                        ),
              ),
            ),
          ),
          if (canShowValueModal && !isValueLoading)
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              icon: Icon(
                Icons.visibility_outlined,
                color: context.colour.secondary,
              ),
              onPressed: () {
                _onShowValueModal(context, canCopy: canCopy);
              },
            ),
          // Only show the copy button if there is something to copy
          if (canCopy)
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              icon: Icon(Icons.copy_sharp, color: context.colour.secondary),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: clipboardText ?? text));
                SnackBarUtils.showCopiedSnackBar(context);
              },
            ),
          const Gap(8),
        ],
      ),
    );
  }

  void _onShowValueModal(BuildContext context, {required bool canCopy}) {
    final theme = context.theme;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            title:
                modalTitle != null
                    ? BBText(
                      modalTitle!,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    )
                    : null,

            content: SingleChildScrollView(
              child: SelectableText(
                modalContent ?? text,
                style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
              ),
            ),
            actions: [
              if (canCopy)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.secondary,
                    textStyle: theme.textTheme.bodyLarge,
                  ),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: clipboardText ?? text),
                    );
                  },
                  child: BBText('Copy', style: theme.textTheme.bodyLarge),
                ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  textStyle: theme.textTheme.bodyLarge,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: BBText('Close', style: theme.textTheme.bodyLarge),
              ),
            ],
          ),
    );
  }
}
