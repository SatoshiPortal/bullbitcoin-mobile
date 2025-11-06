import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RecipientFormContinueButton extends StatelessWidget {
  const RecipientFormContinueButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select(
      (RecipientsBloc bloc) => bloc.state.isLoading,
    );
    return BBButton.big(
      label: 'Continue',
      disabled: isLoading,
      onPressed: onPressed,
      bgColor: context.colour.secondary,
      textColor: context.colour.onSecondary,
    );
  }
}
