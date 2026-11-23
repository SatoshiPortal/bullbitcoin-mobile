import '../../../exchange_l10n.dart';

import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart' show Builder, Icons;

abstract final class ExchangeAccountSheets {
  static Future<void> confirmDeletion(
    BuildContext context, {
    required Future<void> Function() onConfirm,
  }) {
    return _showConfirmation(
      context,
      kind: _Confirmation.deleteAccount,
      onConfirm: onConfirm,
    );
  }

  static Future<void> confirmLogout(
    BuildContext context, {
    required Future<void> Function() onConfirm,
  }) {
    return _showConfirmation(
      context,
      kind: _Confirmation.logout,
      onConfirm: onConfirm,
    );
  }

  static Future<void> showDeletionRequested(BuildContext context) {
    return BullBottomSheet.show<void>(
      context: context,
      isDismissible: false,
      child: Builder(
        builder: (context) {
          final loc = context.loc;
          return _AccountNotice(
            icon: Icons.check_circle_outline,
            title: loc.deleteAccountSuccessTitle,
            description: loc.deleteAccountSuccessDescription,
            descriptionMaxLines: 5,
            actions: SizedBox(
              width: double.infinity,
              child: BullButton.secondary(
                size: BullButtonSize.small,
                label: loc.deleteAccountSuccessClose,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          );
        },
      ),
    );
  }

  static Future<void> _showConfirmation(
    BuildContext context, {
    required _Confirmation kind,
    required Future<void> Function() onConfirm,
  }) {
    return BullBottomSheet.show<void>(
      context: context,
      child: Builder(
        builder: (context) {
          final loc = context.loc;
          final (
            icon,
            title,
            description,
            maxLines,
            cancel,
            confirm,
          ) = switch (kind) {
            _Confirmation.deleteAccount => (
              Icons.delete_forever,
              loc.deleteAccountConfirmationTitle,
              loc.deleteAccountConfirmationDescription,
              5,
              loc.deleteAccountConfirmationCancel,
              loc.deleteAccountConfirmationDelete,
            ),
            _Confirmation.logout => (
              Icons.logout,
              loc.logoutConfirmationTitle,
              loc.logoutConfirmationDescription,
              4,
              loc.logoutConfirmationCancel,
              loc.logoutConfirmationLogout,
            ),
          };
          return _AccountNotice(
            icon: icon,
            title: title,
            description: description,
            descriptionMaxLines: maxLines,
            actions: Row(
              children: [
                Expanded(
                  child: BullButton.secondary(
                    size: BullButtonSize.small,
                    label: cancel,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const Gap(BullSpacing.sm),
                Expanded(
                  child: BullButton.primary(
                    size: BullButtonSize.small,
                    label: confirm,
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await onConfirm();
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

enum _Confirmation { deleteAccount, logout }

class _AccountNotice extends StatelessWidget {
  const _AccountNotice({
    required this.icon,
    required this.title,
    required this.description,
    required this.descriptionMaxLines,
    required this.actions,
  });

  final IconData icon;
  final String title;
  final String description;
  final int descriptionMaxLines;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(BullSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(context.bullShapes.dot),
              ),
            ),
            const Gap(BullSpacing.lg),
            BullIcon(icon, size: BullSpacing.xxl, color: colors.primary),
            const Gap(BullSpacing.md),
            Semantics(
              header: true,
              child: BullText(
                title,
                role: BullTextRole.subtitle,
                fontWeight: FontWeight.bold,
                textAlign: TextAlign.center,
              ),
            ),
            const Gap(BullSpacing.xs),
            BullText(
              description,
              role: BullTextRole.body,
              color: colors.secondary.withValues(alpha: 0.7),
              textAlign: TextAlign.center,
              maxLines: descriptionMaxLines,
              overflow: TextOverflow.ellipsis,
            ),
            const Gap(BullSpacing.lg),
            actions,
          ],
        ),
      ),
    );
  }
}
