import 'package:announcements/generated/l10n/announcements_localizations.dart';
import 'package:bull_ui/bull_ui.dart';

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
  static Future<AnnouncementDismissChoice?> show(
    BuildContext context, {
    required bool canRead,
  }) {
    return BullDialog.show<AnnouncementDismissChoice>(
      context: context,
      builder: (dialogContext) =>
          _AnnouncementDismissDialogBody(dialogContext, canRead: canRead),
    );
  }
}

class _AnnouncementDismissDialogBody extends StatelessWidget {
  const _AnnouncementDismissDialogBody(
    this.dialogContext, {
    required this.canRead,
  });

  final BuildContext dialogContext;
  final bool canRead;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final textTheme = context.bullType;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AnnouncementsLocalizations.of(context)
              .announcementDismissConfirmTitle,
          style: textTheme.body
              .copyWith(fontWeight: FontWeight.w500)
              .copyWith(color: colors.text),
        ),
        const Gap(8),
        Text(
          AnnouncementsLocalizations.of(context).announcementDismissConfirmBody,
          style: textTheme.body.copyWith(color: colors.onSurfaceVariant),
        ),
        const Gap(20),
        Row(
          children: [
            Expanded(
              child: BullButton.secondary(
                size: BullButtonSize.small,
                label: AnnouncementsLocalizations.of(context)
                    .announcementDismissConfirmRead,
                onPressed: canRead
                    ? () =>
                          Navigator.of(dialogContext)
                              .pop(AnnouncementDismissChoice.read)
                    : null,
              ),
            ),
            const Gap(12),
            Expanded(
              child: BullButton.primary(
                size: BullButtonSize.small,
                label: AnnouncementsLocalizations.of(context)
                    .announcementDismissConfirmAction,
                onPressed: () =>
                    Navigator.of(dialogContext)
                        .pop(AnnouncementDismissChoice.dismiss),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
