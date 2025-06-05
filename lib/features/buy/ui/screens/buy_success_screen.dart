import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/timers/countdown.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

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
    final payoutTime =
        buyOrder.scheduledPayoutTime != null
            ? DateTime.tryParse(buyOrder.scheduledPayoutTime!)
            : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        // Pop off the buy shellroute by using the root navigator
        Navigator.of(context, rootNavigator: true).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Buy Bitcoin'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                // Pop off the buy shellroute by using the root navigator
                Navigator.of(context, rootNavigator: true).pop();
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
                BBButton.big(
                  label: 'View details',
                  onPressed: () {
                    //context.pushNamed(TransactionsRoute.transactionDetails.name,extra: );
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
