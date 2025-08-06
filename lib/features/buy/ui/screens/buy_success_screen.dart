import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/timers/countdown.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bb_mobile/features/buy/ui/buy_router.dart';
import 'package:bb_mobile/features/buy/ui/widgets/accelerate_transaction_list_tile.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class BuySuccessScreen extends StatelessWidget {
  const BuySuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final buyOrder = context.select((BuyBloc bloc) => bloc.state.buyOrder!);
    final payoutAmountBtc = buyOrder.payoutAmount;
    final bitcoinUnit = context.select(
      (SettingsCubit cubit) => cubit.state.bitcoinUnit,
    );
    final payoutAmountSat = ConvertAmount.btcToSats(
      payoutAmountBtc,
    ); // Convert sats to BTC
    final formattedPayOutAmount =
        bitcoinUnit == BitcoinUnit.sats
            ? FormatAmount.sats(payoutAmountSat)
            : FormatAmount.btc(buyOrder.payoutAmount);
    final payoutTime = buyOrder.scheduledPayoutTime;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return; // Don't allow back navigation

        // Navigate to the exchange home screen when the user wants to exit the
        // buy success screen.
        context.goNamed(ExchangeRoute.exchangeHome.name);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Buy Bitcoin'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                // Navigate to the exchange home screen after a successful buy
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
                Text(
                  'You bought $formattedPayOutAmount',
                  style: context.font.titleLarge,
                ),
                const SizedBox(height: 10),
                if (payoutTime != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Your payout will be sent in ',
                        style: context.font.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const Gap(4),
                      Countdown(
                        until: payoutTime,
                        onTimeout: () {
                          // TODO: Maybe fetch the order again or notify the user
                        },
                      ),
                    ],
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
                // Only show transaction acceleration option for Bitcoin on-chain
                // orders by checking if the order has a bitcoin address. And only
                // show it if the payout time is not yet scheduled.
                if (buyOrder.bitcoinAddress != null &&
                    buyOrder.transactionId == null)
                  AccelerateTransactionListTile(
                    orderId: buyOrder.orderId,
                    onTap: () {
                      context.pushNamed(
                        BuyRoute.buyAccelerate.name,
                        pathParameters: {'orderId': buyOrder.orderId},
                      );
                    },
                  ),
                const Gap(16),
                BBButton.big(
                  label: 'View details',
                  onPressed: () {
                    context.pushNamed(
                      TransactionsRoute.orderTransactionDetails.name,
                      pathParameters: {'orderId': buyOrder.orderId},
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
