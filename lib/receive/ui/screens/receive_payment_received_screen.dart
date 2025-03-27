import 'package:bb_mobile/_ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/_ui/components/text/text.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:bb_mobile/router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ReceivePaymentReceivedScreen extends StatelessWidget {
  const ReceivePaymentReceivedScreen({
    super.key,
  });

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
        body: const PaymentReceivedPage(),
        // child: AmountPage(),
      ),
    );
  }
}

class PaymentReceivedPage extends StatelessWidget {
  const PaymentReceivedPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
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
        ],
      ),
    );
  }
}
