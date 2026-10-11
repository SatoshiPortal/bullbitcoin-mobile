import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullDialog, BullShapesX, BullShimmerLine, BullSnackBar, Gap;

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
  }) : _content = null,
       _copy = null;

  /// Uses a sealed value renderer and lets its owner perform the copy.
  const CopyInput.content({
    super.key,
    required Widget child,
    required Future<void> Function() onCopy,
  }) : _content = child,
       _copy = onCopy,
       text = '',
       clipboardText = null,
       maxLines = null,
       overflow = null,
       canShowValueModal = false,
       modalTitle = null,
       modalContent = null;

  final Widget? _content;
  final Future<void> Function()? _copy;

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
    final isValueLoading = _content == null && text.isEmpty;
    final canCopy =
        _copy != null ||
        (clipboardText == null && text.isNotEmpty) ||
        (clipboardText != null && clipboardText!.isNotEmpty);

    return Container(
      decoration: BoxDecoration(
        color: context.appColors.onSecondary,
        borderRadius: BorderRadius.circular(context.bullShapes.input),
        border: Border.all(color: context.appColors.secondaryFixedDim),
      ),
      child: Row(
        children: [
          const Gap(15),
          Expanded(
            child: InkWell(
              onTap: canShowValueModal
                  ? () {
                      _onShowValueModal(context, canCopy: canCopy);
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child:
                    _content ??
                    (isValueLoading
                        ? const BullShimmerLine()
                        : Text(
                            text,
                            style: context.font.bodyLarge?.copyWith(
                              color: context.appColors.secondary,
                            ),
                            maxLines: maxLines,
                            overflow: overflow,
                          )),
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
              icon: Icon(Icons.copy_sharp, color: context.appColors.secondary),
              tooltip: context.loc.copyDialogButton,
              onPressed: () async {
                final copy = _copy;
                if (copy != null) {
                  await copy();
                } else {
                  await Clipboard.setData(
                    ClipboardData(text: clipboardText ?? text),
                  );
                }
                if (!context.mounted) return;
                BullSnackBar.show(
                  context,
                  message: context.loc.copiedToClipboard,
                );
              },
            ),
          const Gap(8),
        ],
      ),
    );
  }

  void _onShowValueModal(BuildContext context, {required bool canCopy}) {
    final theme = Theme.of(context);
    BullDialog.show(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dialogContext.bullShapes.sheet),
        ),
        backgroundColor: context.appColors.surface,
        title: modalTitle != null
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
                Clipboard.setData(ClipboardData(text: clipboardText ?? text));
              },
              child: Text(
                context.loc.copyDialogButton,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: context.appColors.primary,
              textStyle: theme.textTheme.bodyLarge,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              context.loc.closeDialogButton,
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
