import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/clipboard_clear.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullDialog, BullShimmerLine, BullSnackBar, Gap;

class CopyInput extends StatefulWidget {
  const CopyInput({
    super.key,
    required this.text,
    this.clipboardText,
    this.maxLines,
    this.overflow,
    this.canShowValueModal = false,
    this.modalTitle,
    this.modalContent,
    this.clearClipboardAfter,
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
  // For secrets: clears the copied value after this delay, or when the widget
  // goes away, unless something else was copied since.
  final Duration? clearClipboardAfter;

  @override
  State<CopyInput> createState() => _CopyInputState();
}

class _CopyInputState extends State<CopyInput> {
  ClipboardClear? _pendingClear;

  String get text => widget.text;
  String? get clipboardText => widget.clipboardText;
  int? get maxLines => widget.maxLines;
  TextOverflow? get overflow => widget.overflow;
  bool get canShowValueModal => widget.canShowValueModal;
  String? get modalTitle => widget.modalTitle;
  String? get modalContent => widget.modalContent;

  @override
  void dispose() {
    // Leaving the screen must not leave the secret behind for the rest of the
    // delay.
    final pending = _pendingClear;
    if (pending != null) unawaited(pending.run());
    super.dispose();
  }

  Future<void> _copy(BuildContext context) async {
    final value = clipboardText ?? text;
    await Clipboard.setData(ClipboardData(text: value));
    final clearAfter = widget.clearClipboardAfter;
    if (clearAfter != null) {
      _pendingClear?.cancel();
      final clear = ClipboardClear(value, clearAfter);
      // Gone while copying: clear right away rather than leave the value.
      if (mounted) {
        _pendingClear = clear;
      } else {
        unawaited(clear.run());
      }
    }
    if (context.mounted) {
      BullSnackBar.show(context, message: context.loc.copiedToClipboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isValueLoading = text.isEmpty;
    final canCopy =
        (clipboardText == null && text.isNotEmpty) ||
        (clipboardText != null && clipboardText!.isNotEmpty);

    return Container(
      decoration: BoxDecoration(
        color: context.appColors.onSecondary,
        borderRadius: BorderRadius.circular(8),
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
                child: isValueLoading
                    ? const BullShimmerLine()
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
              icon: Icon(Icons.copy_sharp, color: context.appColors.secondary),
              onPressed: () => _copy(context),
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
              onPressed: () => _copy(context),
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
