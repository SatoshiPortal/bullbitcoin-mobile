import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core_deprecated/widgets/snackbar_utils.dart';
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
        color: context.appColors.onPrimary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appColors.secondaryFixedDim),
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
                        : Text(
                          text,
                          style: context.font.bodyLarge?.copyWith(
                            color: context.appColors.secondary,
                          ),
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
                color: context.appColors.secondary,
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
              icon: Icon(
                Icons.copy_sharp,
                color: context.appColors.secondary,
              ),
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
            backgroundColor: context.appColors.surface,
            title:
                modalTitle != null
                    ? Text(
                      modalTitle!,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 20,
                        fontWeight: .w700,
                      ),
                      textAlign: .center,
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
                    foregroundColor: context.appColors.secondary,
                    textStyle: theme.textTheme.bodyLarge,
                  ),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: clipboardText ?? text),
                    );
                  },
                  child: Text('Copy', style: theme.textTheme.bodyLarge),
                ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: context.appColors.primary,
                  textStyle: theme.textTheme.bodyLarge,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Close', style: theme.textTheme.bodyLarge),
              ),
            ],
          ),
    );
  }
}
