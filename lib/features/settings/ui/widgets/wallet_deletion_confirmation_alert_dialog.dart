import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WalletDeletionConfirmationAlertDialog extends StatelessWidget {
  const WalletDeletionConfirmationAlertDialog({
    super.key,
    required this.walletId,
  });

  final String walletId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.colour.onPrimary,
      title: const Text('Delete Wallet'),
      content: const Text('Are you sure you want to delete this wallet?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            // Trigger wallet deletion logic
            context.read<WalletBloc>().add(WalletDeleted(walletId));
          },
          child: const Text('Delete'),
        ),
      ],
      actionsAlignment: MainAxisAlignment.spaceBetween,
    );
  }
}
