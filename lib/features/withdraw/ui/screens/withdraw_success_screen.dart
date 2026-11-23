import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:transactions/routes.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullSuccessScreen;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class WithdrawSuccessScreen extends StatelessWidget {
  const WithdrawSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final order = context.select(
      (WithdrawBloc bloc) => bloc.state is WithdrawSuccessState
          ? (bloc.state as WithdrawSuccessState).order
          : null,
    );
    return BullSuccessScreen(
      title: context.loc.withdrawAmountTitle,
      headline: context.loc.withdrawSuccessTitle,
      onClose: () => context.goNamed(ExchangeRoute.exchangeHome.name),
      actions: [
        if (order != null)
          BullButton.secondary(
            label: context.loc.withdrawSuccessOrderDetails,
            onPressed: () {
              TransactionsNavigation.openDetails(
                context,
                TransactionDetailsTarget.order(order.orderId),
                returnToExchange: true,
              );
            },
          ),
      ],
    );
  }
}
