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
      backgroundColor: context.appColors.surface,
      title: Text(
        'Delete Wallet',
        style: context.font.headlineSmall?.copyWith(
          color: context.appColors.error,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        'Are you sure you want to delete this wallet?',
        style: context.font.bodyMedium?.copyWith(
          color: context.appColors.onSurface,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.onSurface,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            context.read<WalletBloc>().add(WalletDeleted(walletId));
          },
          child: Text(
            'Delete',
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
      actionsAlignment: MainAxisAlignment.spaceBetween,
    );
  }
}
