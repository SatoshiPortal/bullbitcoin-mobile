import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
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
      backgroundColor: context.colorScheme.onPrimary,
      title: Text(context.loc.walletDeletionFailedTitle),
      content: Text(
        error is CannotDeleteDefaultWalletError
            ? context.loc.walletDeletionErrorDefaultWallet
            : error is CannotDeleteWalletWithOngoingSwapsError
            ? context.loc.walletDeletionErrorOngoingSwaps
            : error is WalletNotFound
            ? context.loc.walletDeletionErrorWalletNotFound
            : context.loc.walletDeletionErrorGeneric,
        style: context.font.bodyMedium?.copyWith(
          color: context.colorScheme.error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.loc.walletDeletionFailedOkButton),
        ),
      ],
    );
  }
}
