import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';

class FailedWalletDeletionAlertDialog extends StatelessWidget {
  const FailedWalletDeletionAlertDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Failed'),
      content: Text(
        'Failed to delete wallet, please try again.',
        style: context.font.bodyMedium?.copyWith(color: context.colour.error),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
