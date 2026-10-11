import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart' show BullDialog;
import 'package:material_ui/material_ui.dart';

Future<bool> showNostrKeyWarning(
  BuildContext context, {
  required String title,
  required String message,
}) async =>
    await BullDialog.show<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.loc.settingsNostrKeysWarningUnderstand),
          ),
        ],
      ),
    ) ??
    false;
