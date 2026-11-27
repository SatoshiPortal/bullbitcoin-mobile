import 'dart:io' show exit;

import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullButtonSize, BullDialog;
import 'package:material_ui/material_ui.dart';
import 'package:settings/src/l10n.dart';

Future<void> showSettingsRestartDialog(
  BuildContext context, {
  required String message,
  VoidCallback? onClose,
}) {
  return BullDialog.show<void>(
    context: context,
    isDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.loc.networkRestartDialogTitle),
      content: PopScope(canPop: false, child: Text(message)),
      actions: [
        BullButton.primary(
          label: dialogContext.loc.networkRestartDialogAction,
          onPressed: onClose ?? () => exit(0),
          size: BullButtonSize.small,
          compact: true,
        ),
      ],
    ),
  );
}
