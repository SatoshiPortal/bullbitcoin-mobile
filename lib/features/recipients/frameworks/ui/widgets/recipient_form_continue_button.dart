import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class RecipientFormContinueButton extends StatelessWidget {
  const RecipientFormContinueButton({
    super.key,
    required this.onPressed,
    this.hookError,
  });

  final VoidCallback onPressed;
  final String? hookError;

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select(
      (RecipientsBloc bloc) => bloc.state.isLoading,
    );
    final failedToAddRecipient = context.select(
      (RecipientsBloc bloc) => bloc.state.failedToAddRecipient,
    );

    return Column(
      children: [
        if (hookError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              hookError!,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.error,
              ),
            ),
          ),
        if (failedToAddRecipient != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              '$failedToAddRecipient',
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.error,
              ),
            ),
          ),
        BBButton.big(
          label: 'Continue',
          disabled: isLoading,
          onPressed: onPressed,
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
      ],
    );
  }
}
