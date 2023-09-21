import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/bottom_wallet_actions.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/wallet_card.dart';
import 'package:bb_mobile/_ui/wallet_txs.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
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

    return Stack(
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
        const BottomCenter(child: HomeActionButtons()),
      ],
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
    return Material(
      elevation: 1,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          BBButton.text(
            label: 'Backup',
            isBlue: false,
            isRed: true,
            onPressed: () {
              context.push('/wallet-settings/open-backup');
            },
          ),
          BBButton.text(
            label: 'Wallet Details',
            isBlue: false,
            isRed: true,
            onPressed: () {},
          ),
          BBButton.text(
            label: 'Settings',
            isBlue: false,
            onPressed: () {
              context.push('/wallet-settings');
            },
            isRed: true,
          ),
        ],
      ),
    );
  }
}
