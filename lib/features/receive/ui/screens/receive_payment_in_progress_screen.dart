import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/router.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ReceivePaymentInProgressScreen extends StatelessWidget {
  const ReceivePaymentInProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return; // Don't allow back navigation

        context.go(AppRoute.home.path);
      },
      child: Scaffold(
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: TopBar(
            title: 'Receive',
            actionIcon: Icons.close,
            onAction: () {
              context.go(AppRoute.home.path);
            },
          ),
        ),
        body: const PaymentInProgressPage(),
        // child: AmountPage(),
      ),
    );
  }
}

class PaymentInProgressPage extends StatelessWidget {
  const PaymentInProgressPage();

  @override
  Widget build(BuildContext context) {
    // Using read instead of select or watch is ok here,
    //  since the amounts can not be changed at this point anymore.
    final amountBitcoin =
        context.read<ReceiveBloc>().state.formattedConfirmedAmountBitcoin;
    final amountFiat =
        context.read<ReceiveBloc>().state.formattedConfirmedAmountFiat;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BBText(
            'Payment in progress',
            style: context.font.headlineLarge,
          ),
          BBText(
            'It will be confirmed in a few seconds',
            style: context.font.headlineMedium,
          ),
          const Gap(16),
          BBText(
            amountBitcoin,
            style: context.font.headlineLarge,
          ),
          const Gap(4),
          BBText(
            '~$amountFiat',
            style: context.font.bodyLarge,
            color: context.colour.surface,
          ),
        ],
      ),
    );
  }
}
