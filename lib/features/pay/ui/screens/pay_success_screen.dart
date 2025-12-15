import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:bb_mobile/core_deprecated/widgets/buttons/button.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:gif/gif.dart';
import 'package:go_router/go_router.dart';

class PaySuccessScreen extends StatelessWidget {
  const PaySuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final order = context.select(
      (PayBloc bloc) =>
          bloc.state is PaySuccessState
              ? (bloc.state as PaySuccessState).payOrder
              : null,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return; // Don't allow back navigation

        context.goNamed(ExchangeRoute.exchangeHome.name);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.loc.payTitle),
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
              mainAxisAlignment: .center,
              children: [
                Gif(
                  image: AssetImage(Assets.animations.successTick.path),
                  autostart: Autostart.once,
                  height: 100,
                  width: 100,
                ),
                const Gap(20),
                Text(context.loc.payCompleted, style: context.font.titleLarge),
                const Gap(10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    context.loc.payCompletedDescription,
                    style: context.font.bodyMedium,
                    textAlign: .center,
                  ),
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
                if (order != null)
                  BBButton.big(
                    label: context.loc.payViewDetails,
                    onPressed: () {
                      context.pushNamed(
                        TransactionsRoute.orderTransactionDetails.name,
                        pathParameters: {'orderId': order.orderId},
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
