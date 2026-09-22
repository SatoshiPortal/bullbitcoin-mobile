import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_bloc.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_failure_l10n.dart';
import 'package:bb_mobile/features/withdraw/ui/withdraw_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class WithdrawRecipientsScreen extends StatelessWidget {
  const WithdrawRecipientsScreen({super.key});

  Future<void> _selectRecipient(
    BuildContext context,
    RecipientViewModel recipient, {
    required bool isNew,
  }) async {
    if (recipient.type == RecipientType.confidentialSepaEur &&
        !recipient.isVirtualPayeeActive) {
      context.pushNamed(
        WithdrawRoute.withdrawFrPayeeActivation.name,
        extra: FrPayeeActivationArgs(
          recipient: recipient,
          onActivated: (activated) =>
              _selectRecipient(context, activated, isNew: isNew),
          onUseRegularSepa: recipient.supportsRegularSepa
              ? () => _selectRecipient(
                  context,
                  recipient.copyWith(type: RecipientType.sepaEur),
                  isNew: isNew,
                )
              : null,
        ),
      );
      return;
    }

    String? paymentDescription;
    if (recipient.type.supportsPaymentDescription) {
      final state = context.read<WithdrawBloc>().state;
      final retainedDescription = state is WithdrawRecipientInputState
          ? state.paymentDescription
          : null;
      paymentDescription = await context.pushNamed<String>(
        WithdrawRoute.withdrawPaymentDescription.name,
        extra: retainedDescription,
      );
      if (!context.mounted || paymentDescription == null) return;
    }

    context.read<WithdrawBloc>().add(
      WithdrawEvent.recipientSelected(
        recipient,
        isNew: isNew,
        paymentDescription: paymentDescription,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WithdrawBloc, WithdrawState>(
      bloc: context.read<WithdrawBloc>(),
      builder: (context, state) {
        return RecipientsScreen(
          filter: RecipientFilterCriteria(
            types: RecipientType.typesForCurrency(state.currency.code).toList(),
            isOwner: true,
          ),
          onRecipientSelected: (recipient, {required isNew}) async {
            await _selectRecipient(context, recipient, isNew: isNew);
          },
          isHookRunning: state is WithdrawRecipientInputState
              ? state.isCreatingWithdrawOrder
              : false,
          onRecipientAddedHookError: state is WithdrawRecipientInputState
              ? state.newRecipientError?.toTranslated(context)
              : null,
          onRecipientSelectedHookError: state is WithdrawRecipientInputState
              ? state.selectedRecipientError?.toTranslated(context)
              : null,
        );
      },
    );
  }
}
