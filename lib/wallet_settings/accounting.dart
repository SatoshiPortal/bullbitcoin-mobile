import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class Accounting extends StatelessWidget {
  const Accounting({super.key, required this.walletBloc});

  final WalletBloc walletBloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: walletBloc,
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: BBAppBar(
            text: 'Accounting',
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
    final walletName = context.select((WalletBloc _) => _.state.name);
    final totalBalance = context.select((WalletBloc _) => _.state.balance?.total ?? 0);
    final totalStr = context.select(
      (SettingsCubit _) => _.state.getAmountInUnits(totalBalance, removeText: true),
    );
    final confirmedBalance = context.select((WalletBloc _) => _.state.balance?.confirmed ?? 0);
    final confirmedStr = context.select(
      (SettingsCubit _) => _.state.getAmountInUnits(confirmedBalance, removeText: true),
    );
    final unconfirmedBalance =
        context.select((WalletBloc _) => _.state.balance?.untrustedPending ?? 0);
    final unconfirmedStr = context.select(
      (SettingsCubit _) => _.state.getAmountInUnits(unconfirmedBalance, removeText: true),
    );
    final amtSent = context.select(
      (WalletBloc cubit) => cubit.state.wallet!.totalSent(),
    );
    final sentStr = context.select(
      (SettingsCubit _) => _.state.getAmountInUnits(amtSent, removeText: true),
    );
    final amtReceived = context.select(
      (WalletBloc cubit) => cubit.state.wallet!.totalReceived(),
    );
    final receivedStr = context.select(
      (SettingsCubit _) => _.state.getAmountInUnits(amtReceived, removeText: true),
    );
    final txsReceivedCount = context.select(
      (WalletBloc _) => _.state.wallet?.txReceivedCount() ?? 0,
    );
    final txsSentCount = context.select(
      (WalletBloc _) => _.state.wallet?.txSentCount() ?? 0,
    );
    final units = context.select((SettingsCubit x) => x.state.getUnitString());

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const BBText.title('Wallet Name'),
            const Gap(4),
            BBText.body(walletName, isBold: true),
            const Gap(16),
            const BBText.title('Total Balance'),
            const Gap(4),
            BBText.body('$totalStr $units', isBold: true),
            const Gap(16),
            const BBText.title('Trusted Balance (confirmed)'),
            const Gap(4),
            BBText.body('$confirmedStr $units', isBold: true),
            const Gap(16),
            const BBText.title('Untrusted Balance (unconfirmed)'),
            const Gap(4),
            BBText.body('$unconfirmedStr $units', isBold: true),
            const Gap(16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BBText.title('Total amount received'),
                      const Gap(4),
                      BBText.body('$receivedStr $units', isBold: true),
                      const Gap(16),
                      const BBText.title('Transactions Received'),
                      const Gap(4),
                      BBText.body('$txsReceivedCount transactions', isBold: true),
                    ],
                  ),
                ),
                const Spacer(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const BBText.title('Total amount sent', textAlign: TextAlign.right),
                      const Gap(4),
                      BBText.body('$sentStr $units', isBold: true, textAlign: TextAlign.right),
                      const Gap(16),
                      const BBText.title('Transactions Sent', textAlign: TextAlign.right),
                      const Gap(4),
                      BBText.body(
                        '$txsSentCount transactions',
                        isBold: true,
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
