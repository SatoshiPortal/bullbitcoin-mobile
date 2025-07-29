import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SellSuccessScreen extends StatelessWidget {
  const SellSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final order = context.select(
      (SellBloc bloc) =>
          bloc.state is SellSuccessState
              ? (bloc.state as SellSuccessState).sellOrder
              : null,
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return; // Don't allow back navigation
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sell Bitcoin'),
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
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Order completed!',
                  style: context.font.headlineLarge?.copyWith(
                    color: context.colour.outlineVariant,
                  ),
                ),
                const Spacer(),
                if (order != null)
                  BBButton.big(
                    label: 'Order details',
                    onPressed: () {
                      context.pushNamed(
                        TransactionsRoute.orderTransactionDetails.name,
                        pathParameters: {
                          'orderId': order.orderId,
                        }, // Replace with actual order ID
                      );
                    },
                    bgColor: context.colour.secondary,
                    textColor: context.colour.onSecondary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
