import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';

class DeleteCustomServerDialog {
  static Future<bool?> show(
    BuildContext context,
    String serverUrl,
    bool isLastCustomServer,
  ) {
    return showDialog<bool>(
      context: context,

      builder:
          (BuildContext dialogContext) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.onSecondary,
            title: Text(context.loc.electrumDeleteServerTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLastCustomServer)
                  Text(context.loc.electrumDeletePrivacyNotice),
                Text(context.loc.electrumDeleteConfirmation(serverUrl)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(context.loc.electrumCancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(context.loc.electrumDelete),
              ),
            ],
          ),
    );
  }
}
