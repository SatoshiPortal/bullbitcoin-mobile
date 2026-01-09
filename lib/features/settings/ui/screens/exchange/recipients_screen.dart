import 'package:bb_mobile/features/pay/ui/pay_router.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/screens/recipients_screen.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ExchangeRecipientsScreen extends StatelessWidget {
  const ExchangeRecipientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RecipientsBloc>(
      create: (context) => locator<RecipientsBloc>(
        param1: null,
        param2: (RecipientViewModel recipient) async {
          context.pushNamed(PayRoute.pay.name, extra: recipient);
        },
      )..add(const RecipientsEvent.started()),
      child: const RecipientsScreen(),
    );
  }
}
