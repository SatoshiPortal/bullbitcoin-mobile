import 'package:bull_exchange/src/exchange_landing_navigation.dart';
import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/withdraw/presentation/withdraw_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullSuccessScreen;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

class WithdrawSuccessScreen extends StatelessWidget {
  const WithdrawSuccessScreen({required this.openOrder, super.key});

  final void Function(BuildContext, String) openOrder;

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
      onClose: () => BullExchangeNavigation.goToDashboard(context),
      actions: [
        if (order != null)
          BullButton.secondary(
            label: context.loc.withdrawSuccessOrderDetails,
            onPressed: () => openOrder(context, order.orderId),
          ),
      ],
    );
  }
}
