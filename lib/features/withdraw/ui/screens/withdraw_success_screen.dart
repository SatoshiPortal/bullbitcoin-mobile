import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class WithdrawSuccessScreen extends StatelessWidget {
  const WithdrawSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final order = context.select(
      (WithdrawBloc bloc) =>
          bloc.state is WithdrawSuccessState
              ? (bloc.state as WithdrawSuccessState).order
              : null,
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return; // Don't allow back navigation
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.loc.withdrawAmountTitle),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                context.goNamed(ExchangeRoute.exchangeHome.name);
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: context.appColors.secondary,
                        size: 64,
                      ),
                      const Gap(16),
                      Text(
                        context.loc.withdrawSuccessTitle,
                        style: context.font.headlineLarge?.copyWith(
                          color: context.appColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (order != null)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: BBButton.big(
                    label: context.loc.withdrawSuccessOrderDetails,
                    onPressed: () {
                      context.pushNamed(
                        TransactionsRoute.orderTransactionDetails.name,
                        pathParameters: {'orderId': order.orderId},
                      );
                    },
                    bgColor: context.appColors.onSurface,
                    textColor: context.appColors.surface,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
