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
            title: const Text('Delete Custom Server'),
            content: Column(
              children: [
                if (isLastCustomServer)
                  const Text(
                    'Privacy Notice:\n'
                    'Using your own node ensures that no third party can link your IP address with your transactions. '
                    'By deleting your last custom server, you will be connecting to a BullBitcoin server.\n\n',
                  ),
                Text(
                  'Are you sure you want to delete this server?\n\n$serverUrl',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }
}
