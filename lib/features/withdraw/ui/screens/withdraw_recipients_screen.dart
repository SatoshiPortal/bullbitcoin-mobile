import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/screens/recipients_screen.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/recipient_filter_criteria.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WithdrawRecipientsScreen extends StatelessWidget {
  const WithdrawRecipientsScreen({super.key});

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
            context.read<WithdrawBloc>().add(
              WithdrawEvent.recipientSelected(recipient, isNew: isNew),
            );
          },
          isHookRunning: state is WithdrawRecipientInputState
              ? state.isCreatingWithdrawOrder
              : false,
          onRecipientAddedHookError: state is WithdrawRecipientInputState
              ? state.newRecipientError?.toString()
              : null,
          onRecipientSelectedHookError: state is WithdrawRecipientInputState
              ? state.selectedRecipientError?.toString()
              : null,
        );
      },
    );
  }
}
