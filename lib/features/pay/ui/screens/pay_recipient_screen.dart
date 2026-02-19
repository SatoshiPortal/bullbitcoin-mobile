import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/screens/recipients_screen.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/recipient_filter_criteria.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PayRecipientScreen extends StatelessWidget {
  const PayRecipientScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PayBloc, PayState>(
      bloc: context.read<PayBloc>(),
      builder: (context, state) {
        return RecipientsScreen(
          filter: RecipientFilterCriteria(),
          onRecipientSelected: (recipient, {required isNew}) async {
            context.read<PayBloc>().add(PayEvent.recipientSelected(recipient));
          },
        );
      },
    );
  }
}
