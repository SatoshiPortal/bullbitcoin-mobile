import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_ui/components/indicators.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/warning.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:extra_alignments/extra_alignments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
    final loading = context.select((WalletBloc x) => x.state.loading());

    final confirmedTXs = context.select((WalletBloc x) => x.state.wallet?.getConfirmedTxs() ?? []);
    final pendingTXs = context.select((WalletBloc x) => x.state.wallet?.getPendingTxs() ?? []);
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
            horizontal: 48.0,
            vertical: 24,
          ),
          child: const BBText.titleLarge('No Transaction yet').animate(delay: 300.ms).fadeIn(),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
              const BBText.titleLarge('    Confirmed Transactions', isBold: true)
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

class HomeTxItem extends StatelessWidget {
  const HomeTxItem({super.key, required this.tx});

  final Transaction tx;

  @override
  Widget build(BuildContext context) {
    final label = tx.label ?? '';

    final amount = context
        .select((CurrencyCubit x) => x.state.getAmountInUnits(tx.getAmount(sentAsTotal: true)));

    final isReceive = tx.isReceived();

    final amt = '${isReceive ? '' : ''}${amount.replaceAll("-", "")}';

    return InkWell(
      onTap: () {
        context.push('/tx', extra: tx);
      },
      child: Padding(
        padding: const EdgeInsets.only(
          top: 8,
          bottom: 16,
          left: 24,
          right: 8,
        ),
        child: Row(
          children: [
            Container(
              transformAlignment: Alignment.center,
              transform: Matrix4.identity()..rotateZ(isReceive ? 1.6 : -1.6),
              child: const FaIcon(FontAwesomeIcons.arrowRight),
            ),
            const Gap(8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText.titleLarge(amt),
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
    final _ = context.select((WalletBloc x) => x.state.wallet);
    final backupTested = context.select((WalletBloc x) => x.state.wallet?.backupTested ?? true);

    if (backupTested) return const SizedBox.shrink();

    return WarningBanner(
      onTap: () {
        context.push(
          '/wallet-settings/open-backup',
          extra: context.read<WalletBloc>(),
        );
      },
      info: 'Back up your wallet! Tap to test backup.',
    );
  }
}
