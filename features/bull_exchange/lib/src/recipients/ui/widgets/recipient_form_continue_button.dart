import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/recipients/presentation/recipients_bloc.dart';
import 'package:bull_exchange/src/recipients/presentation/recipients_failure_l10n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RecipientFormContinueButton extends StatelessWidget {
  const RecipientFormContinueButton({
    super.key,
    required this.onPressed,
    this.hookError,
    this.formDisabled = false,
  });

  final VoidCallback onPressed;
  final String? hookError;
  final bool formDisabled;

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
              style: context.bullType.body.copyWith(
                color: context.appColors.error,
              ),
            ),
          ),
        if (failedToAddRecipient != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              failedToAddRecipient.toTranslated(context),
              style: context.bullType.body.copyWith(
                color: context.appColors.error,
              ),
            ),
          ),
        BullButton.primary(
          label: context.loc.recipientsContinue,
          onPressed:
              (isLoading ||
                  formDisabled ||
                  failedToAddRecipient is RecipientsSaveOutcomeUnknownFailure)
              ? null
              : onPressed,
        ),
      ],
    );
  }
}
