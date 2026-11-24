import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:user_feedback/src/user_feedback_l10n.dart';

/// A light prompt after a shake, so an accidental shake costs one tap.
/// Resolves to true when the user wants to send feedback.
Future<bool> showShakePrompt(BuildContext context) async {
  final copy = context.feedbackCopy;
  final send = await BullBottomSheet.show<bool>(
    context: context,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: BullText(
                copy.feedbackShakeTitle,
                role: BullTextRole.title,
              ),
            ),
            const SizedBox(height: 4),
            BullText(copy.feedbackShakeBody, role: BullTextRole.body),
            const SizedBox(height: 24),
            BullButton.primary(
              label: copy.feedbackTitle,
              onPressed: () => Navigator.of(sheetContext).pop(true),
            ),
            const SizedBox(height: 8),
            BullButton.secondary(
              label: copy.feedbackShakeDismiss,
              onPressed: () => Navigator.of(sheetContext).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
  return send ?? false;
}
