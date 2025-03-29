import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/receive/ui/receive_router.dart';
import 'package:bb_mobile/router.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ReceivePayjoinInProgressScreen extends StatelessWidget {
  const ReceivePayjoinInProgressScreen({
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
        body: PayjoinInProgressPage(
          receiveState: receiveState,
        ),
        // child: AmountPage(),
      ),
    );
  }
}

class PayjoinInProgressPage extends StatelessWidget {
  const PayjoinInProgressPage({
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
            'Payjoin in progress',
            style: context.font.headlineLarge,
          ),
          BBText(
            'Wait for the sender to finish the payjoin transaction',
            style: context.font.headlineMedium,
          ),
          const Gap(16),
          BBText(
            receiveState.formattedConfirmedAmountBitcoin,
            style: context.font.headlineLarge,
          ),
          const Gap(4),
          BBText(
            '~${receiveState.formattedConfirmedAmountFiat}',
            style: context.font.bodyLarge,
            color: context.colour.surface,
          ),
          const Spacer(),
          BBText(
            "No time to wait or did the payjoin fail on the sender's side?",
            style: context.font.bodyLarge,
          ),
          ReceiveBroadcastPayjoinButton(
            receiveState: receiveState,
          ),
          const Gap(16),
        ],
      ),
    );
  }
}

class ReceiveBroadcastPayjoinButton extends StatelessWidget {
  const ReceiveBroadcastPayjoinButton({super.key, required this.receiveState});

  final ReceiveState receiveState;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: BBButton.big(
        label: 'Receive payment normally',
        onPressed: () {
          // Todo: broadcast the payjoin transaction
          // context.read<ReceiveBloc>().add(const ReceivePayjoinBroadcasted());
          context.go(ReceiveRoute.details.path, extra: receiveState);
        },
        bgColor: context.colour.secondary,
        textColor: context.colour.onSecondary,
      ),
    );
  }
}
