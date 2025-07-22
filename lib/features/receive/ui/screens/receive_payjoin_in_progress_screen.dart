import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
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
        body: const PayjoinInProgressPage(),
      ),
    );
  }
}

class PayjoinInProgressPage extends StatelessWidget {
  const PayjoinInProgressPage();

  @override
  Widget build(BuildContext context) {
    final amountSat = context.select(
      (ReceiveBloc bloc) => bloc.state.payjoin?.amountSat,
    );
    final amountFiat = context.select(
      (ReceiveBloc bloc) => bloc.state.payjoinAmountFiat,
    );
    final fiatCurrencyCode = context.select(
      (ReceiveBloc bloc) => bloc.state.fiatCurrencyCode,
    );

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
            CurrencyText(
              amountSat,
              showFiat: false,
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
            style: context.font.titleSmall,
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
          const Gap(16),
          BBButton.big(
            label: 'Receive payment normally',
            onPressed: () {
              log.info('Receive payment normally');
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
