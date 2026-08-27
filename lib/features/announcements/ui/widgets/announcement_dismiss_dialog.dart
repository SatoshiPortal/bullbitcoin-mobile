import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';

/// Outcome of the announcement dismiss dialog.
enum AnnouncementDismissChoice {
  /// Open the announcement's linked page (same as tapping the card).
  read,

  /// Dismiss the announcement.
  dismiss,
}

/// Dialog shown when the user taps the `×` on an announcement. Offers to either
/// read (open the linked page) or dismiss it. Returns `null` if cancelled
/// (barrier tap).
abstract final class AnnouncementDismissDialog {
  static Future<AnnouncementDismissChoice?> show(BuildContext context) {
    return BullDialog.show<AnnouncementDismissChoice>(
      context: context,
      builder: (dialogContext) => _AnnouncementDismissDialogBody(dialogContext),
    );
  }
}

class _AnnouncementDismissDialogBody extends StatelessWidget {
  const _AnnouncementDismissDialogBody(this.dialogContext);

  final BuildContext dialogContext;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.loc.announcementDismissConfirmTitle,
          style: textTheme.titleMedium?.copyWith(color: colors.text),
        ),
        const Gap(8),
        Text(
          context.loc.announcementDismissConfirmBody,
          style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        const Gap(20),
        Row(
          children: [
            Expanded(
              child: BullButton.small(
                label: context.loc.announcementDismissConfirmRead,
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(AnnouncementDismissChoice.read),
                bgColor: colors.surface,
                textColor: colors.text,
                outlined: true,
                borderColor: colors.outline,
              ),
            ),
            const Gap(12),
            Expanded(
              child: BullButton.small(
                label: context.loc.announcementDismissConfirmAction,
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(AnnouncementDismissChoice.dismiss),
                bgColor: colors.error,
                textColor: colors.onError,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
