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
                const Icon(Icons.check_circle, size: 100, color: Colors.green),
                const SizedBox(height: 20),
                Text('Order completed!', style: context.font.titleLarge),
                const SizedBox(height: 10),
                Text(
                  'Your account balance will be credited after your transaction receives 1 confirmation onchain.',
                  style: context.font.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (order != null)
                  BBButton.big(
                    label: 'View details',
                    onPressed: () {
                      context.pushNamed(
                        TransactionsRoute.orderTransactionDetails.name,
                        pathParameters: {'orderId': order.orderId},
                      );
                    },
                    bgColor: context.colour.secondary,
                    textColor: context.colour.onPrimary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
