import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart'
    show PayjoinStatus;
import 'package:bb_mobile/core/payjoin/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
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
    final isBroadcasting = context.select(
      (ReceiveBloc bloc) => bloc.state.isBroadcastingOriginalTransaction,
    );
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
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3.0),
            child: FadingLinearProgress(
              trigger: isBroadcasting,
              backgroundColor: context.colour.onPrimary,
              foregroundColor: context.colour.primary,
            ),
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
    final isBroadcasted = context.select(
      (ReceiveBloc bloc) =>
          bloc.state.payjoin?.status == PayjoinStatus.completed,
    );

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isBroadcasted) ...[
            Text('Payment in progress', style: context.font.headlineLarge),
            Text(
              'Bitcoin transaction will take a while to confirm.',
              style: context.font.headlineMedium,
            ),
          ] else ...[
            Text('Payjoin in progress', style: context.font.headlineLarge),
            Text(
              'Wait for the sender to finish the payjoin transaction',
              style: context.font.bodyMedium,
            ),
          ],
          if (amountSat != null) ...[
            const Gap(16),
            CurrencyText(
              amountSat,
              showFiat: false,
              style: context.font.headlineLarge,
            ),
            const Gap(4),
            Text(
              '~${FormatAmount.fiat(amountFiat, fiatCurrencyCode)}',
              style: context.font.bodyLarge?.copyWith(
                color: context.colour.surface,
              ),
            ),
          ],
          if (!isBroadcasted) ...[
            const Gap(84),
            const ReceiveBroadcastPayjoinButton(),
          ],
        ],
      ),
    );
  }
}

class ReceiveBroadcastPayjoinButton extends StatelessWidget {
  const ReceiveBroadcastPayjoinButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isBroadcasting = context.select(
      (ReceiveBloc bloc) => bloc.state.isBroadcastingOriginalTransaction,
    );
    final broadcastOriginalTransactionException = context.select(
      (ReceiveBloc bloc) =>
          bloc.state.error is BroadcastOriginalTransactionException
              ? bloc.state.error! as BroadcastOriginalTransactionException
              : null,
    );
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            "No time to wait or did the payjoin fail on the sender's side?",
            style: context.font.titleSmall,
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
          const Gap(16),
          BBButton.big(
            label: 'Receive payment normally',
            disabled: isBroadcasting,
            onPressed: () {
              log.info('Receive payment normally');
              context.read<ReceiveBloc>().add(
                const ReceivePayjoinOriginalTxBroadcasted(),
              );
            },
            bgColor: context.colour.secondary,
            textColor: context.colour.onSecondary,
          ),
          const Gap(16),
          if (broadcastOriginalTransactionException != null) ...[
            Text(
              'Error: ${broadcastOriginalTransactionException.message}',
              style: context.font.bodyMedium?.copyWith(
                color: context.colour.error,
              ),
              textAlign: TextAlign.center,
            ),
            const Gap(16),
          ],
        ],
      ),
    );
  }
}
