import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ReceivePaymentReceivedScreen extends StatelessWidget {
  const ReceivePaymentReceivedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return; // Don't allow back navigation
        context.go(WalletRoute.walletHome.path);
      },
      child: Scaffold(
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: TopBar(
            title: 'Receive',
            actionIcon: Icons.close,
            onAction: () => context.go(WalletRoute.walletHome.path),
          ),
        ),
        body: const PaymentReceivedPage(),
        // child: AmountPage(),
      ),
    );
  }
}

class PaymentReceivedPage extends StatelessWidget {
  const PaymentReceivedPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Using read instead of select or watch is ok here,
    //  since the amounts can not be changed at this point anymore.
    final amountSat = context.read<ReceiveBloc>().state.confirmedAmountSat;
    final lnSwap = context.read<ReceiveBloc>().state.lightningSwap;
    final fees = lnSwap?.fees?.totalFees(amountSat) ?? 0;
    final finalAmount = (amountSat ?? 0) - fees;
    final amountFiat =
        context.read<ReceiveBloc>().state.formattedConfirmedAmountFiat;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Spacer(),
          BBText('Payment received', style: context.font.headlineLarge),
          const Gap(24),
          CurrencyText(
            finalAmount,
            showFiat: false,
            style: context.font.displaySmall,
          ),
          const Gap(4),
          BBText(
            '~$amountFiat',
            style: context.font.bodyLarge,
            color: context.colour.surface,
          ),
          const Spacer(),
          const ReceiveDetailsButton(),
          const Gap(16),
        ],
      ),
    );
  }
}

class ReceiveDetailsButton extends StatelessWidget {
  const ReceiveDetailsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: BBButton.big(
        label: 'Details',
        onPressed: () {
          final transaction = context.read<ReceiveBloc>().state.transaction;
          if (transaction.walletTransaction != null) {
            context.pushNamed(
              TransactionsRoute.transactionDetails.name,
              pathParameters: {'txId': transaction.walletTransaction!.txId},
              queryParameters: {
                'walletId': transaction.walletTransaction!.walletId,
              },
            );
          } else if (transaction.swap != null) {
            context.pushNamed(
              TransactionsRoute.swapTransactionDetails.name,
              pathParameters: {'swapId': transaction.swap!.id},
              queryParameters: {'walletId': transaction.swap!.walletId},
            );
          } else if (transaction.payjoin != null) {
            context.pushNamed(
              TransactionsRoute.payjoinTransactionDetails.name,
              pathParameters: {'payjoinId': transaction.payjoin!.id},
            );
          }
        },
        bgColor: context.colour.secondary,
        textColor: context.colour.onSecondary,
      ),
    );
  }
}
