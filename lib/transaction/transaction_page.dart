import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_pkg/launcher.dart';
import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bb_mobile/_pkg/storage.dart';
import 'package:bb_mobile/_pkg/wallet/read.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/transaction/bloc/state.dart';
import 'package:bb_mobile/transaction/bloc/transaction_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

class TxPage extends StatelessWidget {
  const TxPage({super.key, required this.tx});

  final Transaction tx;

  @override
  Widget build(BuildContext context) {
    final home = locator<HomeCubit>();
    final wallet = home.state.selectedWalletCubit!;
    final txCubit = TransactionCubit(
      tx: tx,
      walletCubit: wallet,
      mempoolAPI: locator<MempoolAPI>(),
      storage: locator<IStorage>(),
      walletUpdate: locator<WalletUpdate>(),
      walletRead: locator<WalletRead>(),
    );
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: txCubit),
        BlocProvider.value(value: wallet),
      ],
      child: BlocListener<TransactionCubit, TransactionState>(
        listenWhen: (previous, current) => previous.tx != current.tx,
        listener: (context, state) async {
          home.updateSelectedWallet(wallet);
        },
        child: const _Screen(),
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    final tx = context.select((TransactionCubit cubit) => cubit.state.tx);
    final label = context.select((TransactionCubit cubit) => cubit.state.tx.label ?? '');

    final toAddresses =
        context.select((TransactionCubit cubit) => cubit.state.tx.outAddresses ?? []);
    final err = context.select((TransactionCubit cubit) => cubit.state.errLoadingAddresses);

    final txid = tx.txid;
    final amt = tx.getAmount().abs();
    final isReceived = tx.isReceived();
    final fees = tx.fee ?? 0;
    final amtStr = context.select(
      (SettingsCubit cubit) => cubit.state.getAmountInUnits(amt, removeText: true),
    );
    final feeStr = context
        .select((SettingsCubit cubit) => cubit.state.getAmountInUnits(fees, removeText: true));
    final units = context.select(
      (SettingsCubit cubit) => cubit.state.getUnitString(),
    );
    final status = tx.timestamp == 0 ? 'Pending' : 'Confirmed';
    final time = tx.timestamp == 0 ? 'Waiting for confirmations' : timeago.format(tx.getDateTime());
    final broadcastTime = tx.getBroadcastDateTime();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        flexibleSpace: BBAppBar(
          text: label.isNotEmpty ? label : 'Transaction',
          onBack: () {
            context.pop();
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Gap(24),
                BBText.title(
                  isReceived ? 'Amount received' : 'Amount sent',
                ),
                const Gap(4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Container(
                      transformAlignment: Alignment.center,
                      transform: Matrix4.identity()..rotateZ(isReceived ? 1 : -1),
                      child: const FaIcon(
                        FontAwesomeIcons.arrowRight,
                        size: 12,
                      ),
                    ),
                    const Gap(8),
                    BBText.titleLarge(
                      amtStr,
                      isBold: true,
                    ),
                    const Gap(4),
                    BBText.title(
                      units,
                      isBold: true,
                    ),
                  ],
                ),
                const Gap(24),
                const BBText.title(
                  'Transaction ID',
                ),
                const Gap(4),
                BBButton.text(
                  onPressed: () {
                    final url = context.read<SettingsCubit>().state.explorerTxUrl(txid);
                    locator<Launcher>().launchApp(url);
                  },
                  label: txid,
                ),
                if (toAddresses.isNotEmpty) ...[
                  const Gap(24),
                  const BBText.title(
                    'Recipient Bitcoin Address',
                  ),
                  const Gap(4),
                  BBButton.text(
                    onPressed: () {
                      final url =
                          context.read<SettingsCubit>().state.explorerAddressUrl(toAddresses.last);
                      locator<Launcher>().launchApp(url);
                    },
                    label: toAddresses.last,
                  ),
                ],
                const Gap(24),
                const BBText.title(
                  'Status',
                ),
                const Gap(4),
                BBText.titleLarge(
                  status,
                  isBold: true,
                ),
                const Gap(24),
                const BBText.title(
                  'Network Fee',
                ),
                const Gap(4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    BBText.titleLarge(
                      feeStr,
                      isBold: true,
                    ),
                    const Gap(4),
                    BBText.title(
                      units,
                      isBold: true,
                    ),
                  ],
                ),
                const Gap(24),
                BBText.title(
                  isReceived ? 'Tranaction received' : 'Transaction sent',
                ),
                const Gap(4),
                BBText.titleLarge(
                  time,
                  isBold: true,
                ),
                if (broadcastTime != null) ...[
                  const Gap(24),
                  const BBText.title(
                    'Sent Time',
                  ),
                  BBText.titleLarge(
                    timeago.format(broadcastTime),
                    isBold: true,
                  ),
                ],
                const Gap(24),
                const BBText.title(
                  'Change Label',
                ),
                const Gap(4),
                const TxLabelTextField(),
                const Gap(24),
                if (err.isNotEmpty) ...[
                  const Gap(32),
                  BBText.errorSmall(
                    err,
                  ),
                ],
                const Gap(100),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TxLabelTextField extends HookWidget {
  const TxLabelTextField({super.key});

  @override
  Widget build(BuildContext context) {
    final storedLabel = context.select((TransactionCubit x) => x.state.tx.label ?? '');
    final showButton = context.select(
      (TransactionCubit x) => x.state.showSaveButton() && storedLabel.isEmpty,
    );
    final label = context.select((TransactionCubit x) => x.state.label);

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 45,
            child: BBTextInput.small(
              disabled: storedLabel.isNotEmpty,
              hint: storedLabel.isNotEmpty ? storedLabel : 'Enter Label',
              value: label,
              onChanged: (value) {
                context.read<TransactionCubit>().labelChanged(value);
              },
            ),
          ),
        ),
        const Gap(8),
        BBButton.smallRed(
          disabled: !showButton,
          onPressed: () {
            FocusScope.of(context).requestFocus(FocusNode());
            context.read<TransactionCubit>().saveLabelClicked();
          },
          label: 'SAVE',
        )
      ],
    );
  }
}
