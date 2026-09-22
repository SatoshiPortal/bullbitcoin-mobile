import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/pay/ui/pay_router.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
            if (recipient.type == RecipientType.confidentialSepaEur &&
                !recipient.isVirtualPayeeActive) {
              final bloc = context.read<PayBloc>();
              context.pushNamed(
                PayRoute.payFrPayeeActivation.name,
                extra: FrPayeeActivationArgs(
                  recipient: recipient,
                  onActivated: (activated) =>
                      bloc.add(PayEvent.recipientSelected(activated)),
                  onUseRegularSepa: recipient.supportsRegularSepa
                      ? () => bloc.add(
                          PayEvent.recipientSelected(
                            recipient.copyWith(type: RecipientType.sepaEur),
                          ),
                        )
                      : null,
                ),
              );
              return;
            }
            context.read<PayBloc>().add(PayEvent.recipientSelected(recipient));
          },
        );
      },
    );
  }
}
