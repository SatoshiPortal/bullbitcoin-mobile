import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/router.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ReceivePaymentReceivedScreen extends StatelessWidget {
  const ReceivePaymentReceivedScreen({
    super.key,
    required this.receiveState,
  });

  final ReceiveState receiveState;

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
        body: PaymentReceivedPage(
          receiveState: receiveState,
        ),
        // child: AmountPage(),
      ),
    );
  }
}

class PaymentReceivedPage extends StatelessWidget {
  const PaymentReceivedPage({
    super.key,
    required this.receiveState,
  });

  final ReceiveState receiveState;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Spacer(),
          BBText(
            'Payment received',
            style: context.font.headlineLarge,
          ),
          const Gap(24),
          BBText(
            receiveState.formattedConfirmedAmountBitcoin,
            style: context.font.displaySmall,
          ),
          const Gap(4),
          BBText(
            '~${receiveState.formattedConfirmedAmountFiat}',
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
  const ReceiveDetailsButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: BBButton.big(
        label: 'Details',
        onPressed: () {},
        bgColor: context.colour.secondary,
        textColor: context.colour.onSecondary,
      ),
    );
  }
}
