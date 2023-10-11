import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/bull_bitcoin_api.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/create.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/repository.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/transaction.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/_ui/fees.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/send/advanced.dart';
import 'package:bb_mobile/send/amount.dart';
import 'package:bb_mobile/send/bloc/send_cubit.dart';
import 'package:bb_mobile/send/bloc/state.dart';
import 'package:bb_mobile/send/psbt.dart';
import 'package:bb_mobile/send/wallet_select.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';

class SendScreen extends StatelessWidget {
  const SendScreen({
    super.key,
    // required this.walletBloc,
    // this.deepLinkUri,
  });

  // final WalletBloc walletBloc;
  // final String? deepLinkUri;

  @override
  Widget build(BuildContext context) {
    final walletBloc = context.select((SelectSendWalletStep _) => _.state.walletBloc);

    if (walletBloc == null) return const SizedBox.shrink();

    final sendCubit = SendCubit(
      hiveStorage: locator<HiveStorage>(),
      secureStorage: locator<SecureStorage>(),
      walletAddress: locator<WalletAddress>(),
      walletTx: locator<WalletTx>(),
      walletSensTx: locator<WalletSensitiveTx>(),
      walletCreate: locator<WalletCreate>(),
      walletSensCreate: locator<WalletSensitiveCreate>(),
      barcode: locator<Barcode>(),
      walletBloc: walletBloc,
      settingsCubit: locator<SettingsCubit>(),
      bullBitcoinAPI: locator<BullBitcoinAPI>(),
      mempoolAPI: locator<MempoolAPI>(),
      fileStorage: locator<FileStorage>(),
      walletRepository: locator<WalletRepository>(),
      walletSensRepository: locator<WalletSensitiveRepository>(),
    );

    // if (deepLinkUri != null) sendCubit.updateAddress(deepLinkUri!);

    return BlocProvider.value(
      value: sendCubit,
      child: BlocProvider.value(
        value: walletBloc,
        child: BlocListener<SendCubit, SendState>(
          listenWhen: (previous, current) => previous.sent != current.sent && current.sent,
          listener: (context, state) {
            context.read<SelectSendWalletStep>().sent();
          }, //context.pop(),
          child: const _Screen(),
        ),
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    final signed = context.select((SendCubit cubit) => cubit.state.signed);
    final sent = context.select((SendCubit cubit) => cubit.state.sent);
    // return Scaffold(
    //   appBar: sent
    //       ? null
    //       : AppBar(
    //           flexibleSpace: const SendAppBar(),
    //           automaticallyImplyLeading: false,
    //         ),
    //   body:
    return ColoredBox(
      color: sent ? Colors.green : context.colour.onPrimary,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (signed) ...[
                if (!sent) const TxDetailsScreen() else const TxSuccess(),
                const Gap(48),
              ] else ...[
                const Gap(24),
                const Center(child: WalletName()),
                const Gap(8),
                const Center(child: WalletBalance()),
                const Gap(48),
                const EnterAmount(),
                const Gap(24),
                const BBText.title('    Address'),
                const Gap(4),
                const EnterAddress(),
                const Gap(24),
                const BBText.title('    Label (optional)'),
                const Gap(4),
                const EnterNote(),
                const Gap(24),
                const SelectFeesButton(),
                const CoinSelectionButton(),
                const Gap(24),
                const AdvancedOptionsButton(),
                const Gap(8),
              ],
              if (!sent) const SendButton(),
              const Gap(80),
            ],
          ),
        ),
      ).animate(delay: 200.ms).fadeIn(),
    );
  }
}

class WalletName extends StatelessWidget {
  const WalletName({super.key});

  @override
  Widget build(BuildContext context) {
    final name = context.select((WalletBloc cubit) => cubit.state.wallet?.name);

    final fingerprint =
        context.select((WalletBloc cubit) => cubit.state.wallet?.sourceFingerprint ?? '');

    return BBText.body(
      name ?? fingerprint,
    );
  }
}

class WalletBalance extends StatelessWidget {
  const WalletBalance({super.key});

  @override
  Widget build(BuildContext context) {
    final balance = context.select((WalletBloc cubit) => cubit.state.balance?.total ?? 0);

    final balStr = context.select((SettingsCubit cubit) => cubit.state.getAmountInUnits(balance));

    return BBText.body(balStr, isBold: true);
  }
}

class EnterAddress extends StatefulWidget {
  const EnterAddress({super.key});

  @override
  State<EnterAddress> createState() => _EnterAddressState();
}

class _EnterAddressState extends State<EnterAddress> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    final address = context.select((SendCubit cubit) => cubit.state.address);
    if (_controller.text != address) {
      _controller.text = address;
      _focusNode.unfocus();
    }
    return BBTextInput.bigWithIcon(
      focusNode: _focusNode,
      hint: 'Enter address',
      value: address,
      rightIcon: FaIcon(
        FontAwesomeIcons.barcode,
        color: context.colour.secondary,
      ),
      onRightTap: () {
        context.read<SendCubit>().scanAddress();
      },
      onChanged: (txt) {
        context.read<SendCubit>().updateAddress(txt);
      },
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }
}

class EnterNote extends StatefulWidget {
  const EnterNote({super.key});

  @override
  State<EnterNote> createState() => _EnterNoteState();
}

class _EnterNoteState extends State<EnterNote> {
  @override
  Widget build(BuildContext context) {
    final note = context.select((SendCubit cubit) => cubit.state.note);

    return BBTextInput.big(
      value: note,
      hint: 'Enter a description',
      onChanged: (txt) {
        context.read<SendCubit>().updateNote(txt);
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class SendButton extends StatelessWidget {
  const SendButton({super.key});

  @override
  Widget build(BuildContext context) {
    final watchOnly = context.select((WalletBloc cubit) => cubit.state.wallet!.watchOnly());

    final sending = context.select((SendCubit cubit) => cubit.state.sending);
    final showSend = context.select((SendCubit cubit) => cubit.state.showSendButton);
    final err = context.select((SendCubit cubit) => cubit.state.errSending);

    final signed = context.select((SendCubit cubit) => cubit.state.signed);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SizedBox(
            width: 250,
            child: BBButton.bigRed(
              disabled: !showSend,
              loading: sending,
              onPressed: () async {
                if (sending) return;
                if (!signed)
                  context.read<SendCubit>().confirmClickedd();
                else
                  context.read<SendCubit>().sendClicked();
                if (watchOnly) {
                  await Future.delayed(100.ms);
                  PSBTPopUp.openPopUp(context);
                }
              },
              label: watchOnly
                  ? 'Generate PSBT'
                  : signed
                      ? sending
                          ? 'Broadcasting'
                          : 'Confirm'
                      : sending
                          ? 'Building Tx'
                          : 'Send',
            ),
          ),
        ),
        const Gap(8),
        if (err.isNotEmpty)
          Center(
            child: BBText.body(
              err,
            ),
          ),
      ],
    );
  }
}

class AdvancedOptionsButton extends StatelessWidget {
  const AdvancedOptionsButton({super.key});

  @override
  Widget build(BuildContext context) {
    final text = context.select((SendCubit cubit) => cubit.state.advancedOptionsButtonText());
    return BBButton.text(
      centered: true,
      onPressed: () {
        AdvancedOptionsPopUp.openPopup(context);
      },
      label: text,
    );
  }
}

class CoinSelectionButton extends StatelessWidget {
  const CoinSelectionButton({super.key});

  @override
  Widget build(BuildContext context) {
    final totalUTXOsSelected =
        context.select((SendCubit cubit) => cubit.state.totalUTXOsSelected());

    if (totalUTXOsSelected == 0) return Container();

    final totalSelected = context.select((SendCubit cubit) => cubit.state.calculateTotalSelected());
    final amtStr = context
        .select((SettingsCubit _) => _.state.getAmountInUnits(totalSelected, removeText: true));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Gap(8),
        BBButton.textWithStatusAndRightArrow(
          isBlue: true,
          onPressed: () {
            AddressSelectionPopUp.openPopup(context);
          },
          statusText: totalUTXOsSelected.toString(),
          label: 'Coins selected',
        ),
        const Gap(8),
        BBButton.textWithStatusAndRightArrow(
          isBlue: true,
          onPressed: () {
            AddressSelectionPopUp.openPopup(context);
          },
          statusText: amtStr,
          label: 'Amount selected',
        ),
      ],
    );
  }
}

class TxSent extends StatelessWidget {
  const TxSent({super.key});

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class TxDetailsScreen extends StatelessWidget {
  const TxDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final address = context.select((SendCubit cubit) => cubit.state.address);
    final amount = context.select((SendCubit cubit) => cubit.state.amount);
    final amtStr = context.select((SettingsCubit cubit) => cubit.state.getAmountInUnits(amount));
    final amtFiat = context.select((SettingsCubit cubit) => cubit.state.calculatePrice(amount));
    final fee = context.select((SendCubit cubit) => cubit.state.psbtSignedFeeAmount ?? 0);
    final feeStr = context.select((SettingsCubit cubit) => cubit.state.getAmountInUnits(fee));
    final feeFiat = context.select((SettingsCubit cubit) => cubit.state.calculatePrice(fee));
    final fiatCurrency =
        context.select((SettingsCubit cubit) => cubit.state.currency?.shortName ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Gap(24),
        const BBText.body(
          'Confirm Transaction',
          textAlign: TextAlign.center,
        ),
        const Gap(32),
        const BBText.body(
          'You are about to send',
        ),
        const Gap(4),
        BBText.body(
          amtStr,
        ),
        BBText.body(
          '~ $amtFiat $fiatCurrency ',
        ),
        const Gap(24),
        const BBText.body(
          'To this Bitcoin address',
        ),
        const Gap(4),
        BBText.body(
          address,
        ),
        const Gap(24),
        const BBText.body(
          'Network Fee',
        ),
        const Gap(4),
        BBText.body(
          feeStr,
        ),
        BBText.body(
          '~ $feeFiat $fiatCurrency',
        ),
        const Gap(32),
      ],
    );
  }
}

class TxSuccess extends StatelessWidget {
  const TxSuccess({super.key});

  @override
  Widget build(BuildContext context) {
    final amount = context.select((SendCubit cubit) => cubit.state.amount);
    final amtStr = context.select((SettingsCubit cubit) => cubit.state.getAmountInUnits(amount));
    //final txid = context.select((SendCubit cubit) => cubit.state.tx);
    return AnnotatedRegion(
      value: const SystemUiOverlayStyle(statusBarColor: Colors.green),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(152),
          const Icon(Icons.check_circle, size: 120),
          const Gap(32),
          const BBText.body(
            'Transaction sent',
            textAlign: TextAlign.center,
            isBold: true,
          ),
          const Gap(52),
          BBText.titleLarge(
            amtStr,
            textAlign: TextAlign.center,
            isBold: true,
          ),
          const Gap(15),
          GestureDetector(
            onTap: () {
              // final url = context.read<SettingsCubit>().state.explorerTxUrl(txid!.txid);
              // locator<Launcher>().launchApp(url);
            },
            child: const BBText.body(
              'View Transaction details ->',
              textAlign: TextAlign.center,
            ),
          ),
          const Gap(200),
          const Gap(100),
          SizedBox(
            height: 52,
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const BBText.titleLarge(
                'Done',
                textAlign: TextAlign.center,
                isBold: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
