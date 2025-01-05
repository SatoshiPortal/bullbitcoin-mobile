import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_repository/app_wallets_repository.dart';
import 'package:bb_mobile/_repository/network_repository.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/indicators.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/warning.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/settings/bloc/lighting_cubit.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:extra_alignments/extra_alignments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

class WalletTxList extends StatelessWidget {
  const WalletTxList({super.key});

  @override
  Widget build(BuildContext context) {
    // final syncing = context.select((WalletBloc x) => x.state.syncing);
    // final loading = context.select((WalletBloc x) => x.state.loadingTxs);
    // final loadingBal = context.select((WalletBloc x) => x.state.loadingBalance);
    final loading = context.select((WalletBloc x) => x.state.syncing);

    final confirmedTXs =
        context.select((WalletBloc x) => x.state.wallet.getConfirmedTxs());
    final pendingTXs =
        context.select((WalletBloc x) => x.state.wallet.getPendingTxs());
    final zeroPending = pendingTXs.isEmpty;

    if (loading && confirmedTXs.isEmpty && pendingTXs.isEmpty) {
      return TopCenter(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 48.0,
            vertical: 24,
          ),
          child: SizedBox(
            height: 32,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: const BBLoadingRow().animate().fadeIn(),
            ),
          ),
        ),
      );
    }

    if (confirmedTXs.isEmpty && pendingTXs.isEmpty) {
      return TopLeft(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 32.0,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BBText.titleLarge('No Transactions yet')
                  .animate(delay: 300.ms)
                  .fadeIn(),
              BBButton.text(
                label: 'Sync transactions',
                fontSize: 11,
                onPressed: () {
                  final network =
                      context.read<NetworkRepository>().getBBNetwork;
                  final wallets = context
                      .read<AppWalletsRepository>()
                      .walletServiceFromNetwork(network);
                  for (final wallet in wallets) {
                    wallet.syncWallet();
                  }
                },
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loading)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: SizedBox(
                height: 32,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: const BBLoadingRow().animate().fadeIn(),
                ),
              ),
            )
          else
            const Gap(40),
          if (pendingTXs.isNotEmpty) ...[
            const BBText.titleLarge('    Pending Transactions', isBold: true),
            ...pendingTXs.map((tx) => HomeTxItem(tx: tx)),
            const Gap(32),
          ],
          if (confirmedTXs.isNotEmpty) ...[
            if (!zeroPending)
              const BBText.titleLarge(
                '    Confirmed Transactions',
                isBold: true,
              )
            else
              const BBText.titleLarge('    Transactions', isBold: true),
            const Gap(8),
            ...confirmedTXs.map((tx) => HomeTxItem(tx: tx)),
            const Gap(100),
          ],
        ],
      ),
    ).animate().fadeIn();
  }
}

// From walletpage
class HomeTxItem extends StatelessWidget {
  const HomeTxItem({super.key, required this.tx});

  final Transaction tx;

  @override
  Widget build(BuildContext context) {
    // final label = tx.label ?? '';
    final label = (tx.label != null && tx.label!.length > 20)
        ? '${tx.label!.substring(0, 20)}...'
        : tx.label ?? '';
    final isReceive = tx.isReceived();

    var amount = context.select(
      (CurrencyCubit x) => x.state.getAmountInUnits(
        isReceive ? tx.getNetAmountToPayee() : tx.getNetAmountIncludingFees(),
        isLiquid: tx.isLiquid,
      ),
    );

    amount = '${isReceive ? '' : ''}${amount.replaceAll("-", "")}';

    // final amt = '${isReceive ? '' : ''}${amount.replaceAll("-", "")}';

    final darkMode = context.select(
      (Lighting x) => x.state.currentTheme(context) == ThemeMode.dark,
    );

    // final isChainSwap = tx.isSwap && tx.swapTx!.isChainSwap();
    const imgBaseName = 'assets/images/arrow_down';
    final img = darkMode ? '${imgBaseName}_white.png' : '$imgBaseName.png';
    final isChainSwap = tx.isSwap && tx.swapTx!.isChainSwap();
    final isChainReceive = isChainSwap && tx.swapTx!.isChainReceive();

    return InkWell(
      onTap: () {
        context.push('/tx', extra: [tx, false]);
      },
      child: Padding(
        padding: const EdgeInsets.only(
          top: 8,
          bottom: 8,
          left: 24,
          right: 8,
        ),
        child: Row(
          children: [
            SizedBox(
              height: 24,
              width: 14,
              child: Container(
                // color: Colors.red,
                transformAlignment: Alignment.center,
                transform: Matrix4.identity()
                  ..rotateZ(
                    // tx.getNetAmountToPayee() > 0
                    isReceive || isChainReceive ? 0 : 3.16,
                  ),
                child: Image.asset(img),
              ),
            ),
            const Gap(8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText.titleLarge(amount),
                if (label.isNotEmpty) ...[
                  const Gap(4),
                  BBText.bodySmall(label),
                ],
              ],
            ),
            const Spacer(),
            if (tx.getBroadcastDateTime() != null)
              BBText.bodySmall(
                timeago.format(tx.getBroadcastDateTime()!),
                removeColourOpacity: true,
              )
            else
              BBText.bodySmall(
                (tx.timestamp == 0) ? 'Pending' : tx.getDateTimeStr(),
                // : timeago.format(tx.getDateTime()),
                removeColourOpacity: true,
              ),
            // Align(
            //   alignment: Alignment.bottomRight,
            //   child: BBText.bodySmall(
            //     label,
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}

class BackupAlertBanner extends StatelessWidget {
  const BackupAlertBanner({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final wallet = context.select((WalletBloc x) => x.state.wallet);
    final backupTested =
        context.select((WalletBloc x) => x.state.wallet.backupTested);

    if (backupTested) return const SizedBox.shrink();

    return WarningBanner(
      onTap: () {
        context.push(
          '/wallet-settings/open-backup',
          extra: wallet.id,
        );
      },
      info: 'Back up your wallet! Tap to test backup.',
    );
  }
}
