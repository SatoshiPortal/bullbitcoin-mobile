import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: EdgeInsets.zero,
      content: Text(
        'Are you sure you want to delete this wallet?',
        style: context.font.bodyLarge?.copyWith(
          color: context.colour.secondary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: context.font.bodyMedium?.copyWith(
              color: context.colour.secondary,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            // Trigger wallet deletion logic
            context.read<WalletBloc>().add(WalletDeleted(walletId));
          },
          child: Text(
            'Delete',
            style: context.font.bodyMedium?.copyWith(
              color: context.colour.error,
            ),
          ),
        ),
      ],
      actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      buttonPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      titlePadding: const EdgeInsets.all(24),
      title: Text(
        'Delete Wallet',
        style: context.font.headlineMedium?.copyWith(
          color: context.colour.secondary,
        ),
      ),
      titleTextStyle: context.font.headlineMedium?.copyWith(
        color: context.colour.secondary,
      ),
      contentTextStyle: context.font.bodyLarge?.copyWith(
        color: context.colour.secondary,
      ),
    );
  }
}
