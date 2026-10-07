import 'dart:async';
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
class CopyInput extends StatefulWidget {
  final String value;
  final bool canShowValueModal;
  final int? maxLines;
  final String? clipboardText;
  final TextOverflow? overflow;
  final String? modalTitle;
  final Object? modalContent;

  /// Opt-in: clears the copied value from the clipboard after this delay, or
  /// as soon as the widget goes away, unless something else was copied since.
  /// When the app is in the background at that moment, the clear happens on
  /// its next return to the foreground.
  final Duration? clearClipboardAfter;

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
    this.clearClipboardAfter,
  }) : value = value ?? text ?? '';

  @override
  State<CopyInput> createState() => _CopyInputState();
}

class _CopyInputState extends State<CopyInput> {
  _ClipboardClear? _pendingClear;

  String get value => widget.value;
  bool get canShowValueModal => widget.canShowValueModal;
  int? get maxLines => widget.maxLines;
  TextOverflow? get overflow => widget.overflow;
  String? get modalTitle => widget.modalTitle;
  Object? get modalContent => widget.modalContent;

  @override
  void dispose() {
    // Leaving the screen must not leave the secret behind for the rest of the
    // delay, nor a timer that outlives the widget.
    final pending = _pendingClear;
    if (pending != null) unawaited(pending.run());
    super.dispose();
  }

  Future<void> _copy(BuildContext context, String copyValue) async {
    await Clipboard.setData(ClipboardData(text: copyValue));
    final clearAfter = widget.clearClipboardAfter;
    if (clearAfter != null && mounted) {
      _pendingClear?.cancel();
      _pendingClear = _ClipboardClear(copyValue, clearAfter);
    }
    if (context.mounted) {
      BullSnackBar.show(context, message: context.loc.copyDialogCopied);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copyValue = widget.clipboardText ?? value;
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
              onPressed: () => _copy(context, copyValue),
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
                onPressed: () => _copy(context, copyValue),
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

/// Clears one copied value from the clipboard unless something else was copied
/// since. Android 10+ hides the clipboard from an app in the background, so a
/// clipboard that cannot be read is cleared on the next return to the app
/// rather than left holding the value.
final class _ClipboardClear {
  final String _copied;
  Timer? _timer;
  AppLifecycleListener? _resumeListener;
  bool _finished = false;

  _ClipboardClear(this._copied, Duration after) {
    _timer = Timer(after, () => unawaited(run()));
  }

  Future<void> run({bool lastAttempt = false}) async {
    if (_finished) return;
    _timer?.cancel();
    _timer = null;
    final ClipboardData? current;
    try {
      current = await Clipboard.getData(Clipboard.kTextPlain);
    } on PlatformException {
      // The clipboard could not be read; never clear what may not be ours.
      cancel();
      return;
    }
    if (_finished) return;
    if (current == null && !lastAttempt) {
      _resumeListener ??= AppLifecycleListener(
        onResume: () => unawaited(run(lastAttempt: true)),
      );
      return;
    }
    cancel();
    if (current?.text == _copied) {
      await Clipboard.setData(const ClipboardData(text: ''));
    }
  }

  void cancel() {
    _finished = true;
    _timer?.cancel();
    _timer = null;
    _resumeListener?.dispose();
    _resumeListener = null;
  }
}
