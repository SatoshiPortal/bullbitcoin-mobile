import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FailedWalletDeletionAlertDialog extends StatelessWidget {
  const FailedWalletDeletionAlertDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final error = context.select(
      (WalletBloc bloc) => bloc.state.walletDeletionError,
    );
    return AlertDialog(
      backgroundColor: context.colour.onPrimary,
      title: const Text('Delete Failed'),
      content: Text(
        error is CannotDeleteDefaultWalletError
            ? 'You cannot delete a default wallet.'
            : error is CannotDeleteWalletWithOngoingSwapsError
            ? 'You cannot delete a wallet with ongoing swaps.'
            : error is WalletNotFound
            ? 'The wallet you are trying to delete does not exist.'
            : 'Failed to delete wallet, please try again.',
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
