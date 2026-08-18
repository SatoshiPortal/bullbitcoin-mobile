import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart';

class DeleteCustomServerDialog {
  static Future<bool?> show(
    BuildContext context,
    String serverUrl,
    bool isLastCustomServer,
  ) {
    return BullDialog.show<bool>(
      context: context,
      builder: (dialogContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.loc.electrumDeleteServerTitle),
          const Gap(12),
          if (isLastCustomServer)
            Text(
              context.loc.electrumDeletePrivacyNotice,
              style: context.font.bodyMedium,
            ),
          Text(
            context.loc.electrumDeleteConfirmation(serverUrl),
            style: context.font.bodyMedium,
          ),
          const Gap(20),
          Row(
            children: [
              Expanded(
                child: BullButton.secondary(
                  label: context.loc.electrumCancel,
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
              ),
              const Gap(12),
              Expanded(
                child: BullButton.danger(
                  label: context.loc.electrumDelete,
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
