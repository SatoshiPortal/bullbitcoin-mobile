import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/router.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ReceiveDetailsScreen extends StatelessWidget {
  const ReceiveDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
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
        body: const DetailsPage(),
        // child: AmountPage(),
      ),
    );
  }
}

class DetailsPage extends StatelessWidget {
  const DetailsPage();

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
            'TODO: DETAILS',
            style: context.font.headlineLarge,
          ),
          BBText(
            'Payment received',
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
