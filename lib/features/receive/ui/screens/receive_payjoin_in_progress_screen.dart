import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ReceivePayjoinInProgressScreen extends StatelessWidget {
  const ReceivePayjoinInProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: PopScope can be removed since we can do pop here now
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return; // Don't allow back navigation

        context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: TopBar(
            title: 'Receive',
            actionIcon: Icons.close,
            onAction: context.pop,
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
    final amountSat = context.watch<ReceiveBloc>().state.payjoin?.amountSat;
    final amountFiat = context.watch<ReceiveBloc>().state.payjoinAmountFiat;
    final fiatCurrencyCode =
        context.watch<ReceiveBloc>().state.fiatCurrencyCode;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BBText('Payjoin in progress', style: context.font.headlineLarge),
          BBText(
            'Wait for the sender to finish the payjoin transaction',
            style: context.font.bodyMedium,
          ),
          if (amountSat != null) ...[
            const Gap(16),
            BBText(
              FormatAmount.sats(amountSat),
              style: context.font.headlineLarge,
            ),
            const Gap(4),
            BBText(
              '~${FormatAmount.fiat(amountFiat, fiatCurrencyCode)}',
              style: context.font.bodyLarge,
              color: context.colour.surface,
            ),
          ],
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
