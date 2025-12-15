import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:bb_mobile/core_deprecated/widgets/buttons/button.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class BuyAccelerateSuccessScreen extends StatelessWidget {
  const BuyAccelerateSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final buyOrder = context.select((BuyBloc bloc) => bloc.state.buyOrder);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return; // Don't allow back navigation

        // Navigate to the wallet home screen when the user wants to exit the
        // buy success screen.
        context.goNamed(WalletRoute.walletHome.name);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.loc.buyConfirmTitle),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                context.goNamed(WalletRoute.walletHome.name);
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: .center,
              children: [
                Icon(Icons.check_circle, size: 100, color: context.appColors.success),
                const SizedBox(height: 20),
                Text(
                  context.loc.buyBitcoinSent,
                  style: context.font.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  context.loc.buyThatWasFast,
                  style: context.font.bodyMedium,
                  textAlign: .center,
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: .min,
              children: [
                if (buyOrder != null)
                  BBButton.big(
                    label: context.loc.buyViewDetails,
                    onPressed: () {
                      context.pushNamed(
                        TransactionsRoute.orderTransactionDetails.name,
                        pathParameters: {'orderId': buyOrder.orderId},
                      );
                    },
                    bgColor: context.appColors.secondary,
                    textColor: context.appColors.onPrimary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
