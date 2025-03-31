import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/router.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ReceivePayjoinInProgressScreen extends StatelessWidget {
  const ReceivePayjoinInProgressScreen({
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
        body: const PayjoinInProgressPage(),
      ),
    );
  }
}

class PayjoinInProgressPage extends StatelessWidget {
  const PayjoinInProgressPage();

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
            'Payjoin in progress',
            style: context.font.headlineLarge,
          ),
          BBText(
            'Wait for the sender to finish the payjoin transaction',
            style: context.font.bodyMedium,
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
          const Gap(84),
          const ReceiveBroadcastPayjoinButton(),
        ],
      ),
    );
  }
}

class ReceiveBroadcastPayjoinButton extends StatelessWidget {
  const ReceiveBroadcastPayjoinButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          BBText(
            "No time to wait or did the payjoin fail on the sender's side?",
            style: context.font.titleMedium,
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
          const Gap(16),
          BBButton.big(
            label: 'Receive payment normally',
            onPressed: () {
              debugPrint('Receive payment normally');
              context.read<ReceiveBloc>().add(
                    const ReceivePayjoinOriginalTxBroadcasted(),
                  );
            },
            bgColor: context.colour.secondary,
            textColor: context.colour.onSecondary,
          ),
        ],
      ),
    );
  }
}
