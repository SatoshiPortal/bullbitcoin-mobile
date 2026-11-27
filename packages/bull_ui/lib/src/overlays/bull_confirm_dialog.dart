import 'package:bull_ui/src/buttons/bull_button.dart';
import 'package:bull_ui/src/layout/gap.dart';
import 'package:bull_ui/src/overlays/bull_dialog.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:bull_ui/src/theme/bull_typography.dart';
import 'package:material_ui/material_ui.dart';

/// Yes/no confirmation in the kit's [BullDialog] shell: a title, a message and
/// a secondary cancel button and a primary confirmation button.
/// [destructive] remains accepted for compatibility during migration.
///
/// The kit has no localisation, so every label comes translated from the
/// caller.
class BullConfirmDialog extends StatelessWidget {
  const BullConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    this.destructive = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  /// Shows the dialog and completes with `true` only when the user confirms;
  /// cancelling or dismissing it completes with `false`. With [isDismissible]
  /// false, a tap outside the dialog does not close it.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required String cancelLabel,
    bool destructive = false,
    bool isDismissible = true,
  }) async {
    final confirmed = await BullDialog.show<bool>(
      context: context,
      isDismissible: isDismissible,
      builder: (_) => BullConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final type = context.bullType;
    // As AlertDialog does: the dialog scopes its own route and its title
    // names it, so a screen reader announces the title when it opens.
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            namesRoute: true,
            container: true,
            child: Text(
              title,
              style: type.subtitle.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Gap(BullSpacing.sm),
          Text(
            message,
            style: type.label.copyWith(
              color: colors.textMuted,
              fontWeight: FontWeight.w400,
            ),
          ),
          const Gap(BullSpacing.lg),
          Row(
            children: [
              Expanded(
                child: BullButton.secondary(
                  size: BullButtonSize.small,
                  label: cancelLabel,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const Gap(BullSpacing.sm),
              Expanded(
                child: BullButton.primary(
                  size: BullButtonSize.small,
                  label: confirmLabel,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
