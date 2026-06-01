import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
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
        context.loc.walletDeletionConfirmationTitle,
        style: context.font.headlineSmall?.copyWith(
          color: context.appColors.error,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        context.loc.walletDeletionConfirmationMessage,
        style: context.font.bodyMedium?.copyWith(
          color: context.appColors.onSurface,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            context.loc.walletDeletionConfirmationCancelButton,
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
            context.loc.walletDeletionConfirmationDeleteButton,
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
