import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/bottom_wallet_actions.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bb_mobile/wallet/wallet_card.dart';
import 'package:bb_mobile/wallet/wallet_txs.dart';
import 'package:extra_alignments/extra_alignments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class WalletPage extends StatelessWidget {
  const WalletPage({super.key, required this.walletBloc});

  final WalletBloc walletBloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: walletBloc,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          flexibleSpace: BBAppBar(
            text: 'Wallet',
            onBack: () {
              context.pop();
            },
          ),
        ),
        body: const _Screen(),
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    final backupTested = context.select((WalletBloc x) => x.state.wallet?.backupTested ?? false);

    return RefreshIndicator(
      onRefresh: () async {
        context.read<WalletBloc>().add(SyncWallet());
        return;
      },
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: <Widget>[
                const WalletHeader(),
                const ActionsRow(),
                if (!backupTested) ...[
                  const Gap(24),
                  const BackupAlertBanner(),
                  // const Gap(24),
                ],
                const WalletTxList(),
              ],
            ),
          ),
          BottomCenter(
            child: HomeActionButtons(
              walletBloc: context.read<WalletBloc>(),
            ),
          ),
        ],
      ),
    );
  }
}

class WalletHeader extends StatelessWidget {
  const WalletHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Hero(
      tag: 'wallet-card',
      child: SizedBox(
        height: 150,
        child: WalletCardDetails(hideSettings: true),
      ),
    );
  }
}

class ActionsRow extends StatelessWidget {
  const ActionsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final backupTested = context.select((WalletBloc x) => x.state.wallet?.backupTested ?? false);
    final watchonly = context.select((WalletBloc x) => x.state.wallet?.watchOnly() ?? false);

    return Material(
      elevation: 1,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (!watchonly)
            BBButton.text(
              label: 'Backup',
              isBlue: false,
              isRed: !backupTested,
              onPressed: () {
                final walletBloc = context.read<WalletBloc>();
                context.push('/wallet-settings/open-backup', extra: walletBloc);
              },
            ),
          BBButton.text(
            label: 'Wallet Details',
            isBlue: false,
            onPressed: () {
              context.push('/wallet/details', extra: context.read<WalletBloc>());
            },
          ),
          BBButton.text(
            label: 'Settings',
            isBlue: false,
            onPressed: () {
              final walletBloc = context.read<WalletBloc>();
              context.push('/wallet-settings', extra: walletBloc);
            },
          ),
        ],
      ),
    );
  }
}
