import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/bull_bitcoin_api.dart';
import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bb_mobile/_pkg/storage.dart';
import 'package:bb_mobile/_pkg/wallet/read.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/_ui/fees.dart';
import 'package:bb_mobile/_ui/popup_border.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/send/advanced.dart';
import 'package:bb_mobile/send/bloc/send_cubit.dart';
import 'package:bb_mobile/send/bloc/state.dart';
import 'package:bb_mobile/send/psbt.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/wallet/bloc/wallet_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

class SendPopup extends StatelessWidget {
  const SendPopup({super.key});

  static Future openSendPopUp(
    BuildContext context,
    WalletCubit walletCubit,
  ) {
    final cubit = SendCubit(
      storage: locator<IStorage>(),
      walletRead: locator<WalletRead>(),
      walletUpdate: locator<WalletUpdate>(),
      barcodeService: locator<Barcode>(),
      walletCubit: walletCubit,
      settingsCubit: locator<SettingsCubit>(),
      bullBitcoinAPI: locator<BullBitcoinAPI>(),
      mempoolAPI: locator<MempoolAPI>(),
    );

    return showMaterialModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BlocProvider.value(
        value: cubit,
        child: BlocProvider.value(
          value: walletCubit,
          child: BlocListener<SendCubit, SendState>(
            listenWhen: (previous, current) => previous.sent != current.sent,
            listener: (context, state) {
              if (state.sent) context.pop();
            },
            child: const SendPopup(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const PopUpBorder(child: _Screen());
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    final signed = context.select((SendCubit cubit) => cubit.state.signed);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (signed)
            const TxDetailsScreen()
          else ...[
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
            const BBText.title('    Note to self (private)'),
            const Gap(4),
            const EnterNote(),
            const Gap(24),
            const Align(
              alignment: Alignment.centerLeft,
              child: AdvancedOptionsButton(),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: SelectFeesButton(),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: CoinSelectionButton(),
            ),
          ],
          const Gap(48),
          const SendButton(),
          const Gap(80),
        ],
      ),
    );
  }
}

class WalletName extends StatelessWidget {
  const WalletName({super.key});

  @override
  Widget build(BuildContext context) {
    final name =
        context.select((WalletCubit cubit) => cubit.state.wallet?.name);

    final fingerprint = context.select(
        (WalletCubit cubit) => cubit.state.wallet?.cleanFingerprint() ?? '');

    return BBText.body(
      name ?? fingerprint,
    );
  }
}

class WalletBalance extends StatelessWidget {
  const WalletBalance({super.key});

  @override
  Widget build(BuildContext context) {
    final balance =
        context.select((WalletCubit cubit) => cubit.state.balance?.total ?? 0);

    final balStr = context
        .select((SettingsCubit cubit) => cubit.state.getAmountInUnits(balance));

    return BBText.body('Available: ' + balStr);
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

class EnterAmount extends StatefulWidget {
  const EnterAmount({super.key});

  @override
  State<EnterAmount> createState() => _EnterAmountState();
}

class _EnterAmountState extends State<EnterAmount> {
  final FocusNode _focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    final sendAll =
        context.select((SendCubit cubit) => cubit.state.sendAllCoin);
    if (sendAll) return const SizedBox.shrink();
    final balance =
        context.select((WalletCubit cubit) => cubit.state.balance?.total ?? 0);
    final isSats =
        context.select((SettingsCubit cubit) => cubit.state.unitsInSats);
    final amount = context.select((SendCubit cubit) => cubit.state.amount);

    final amountStr = context.select(
      (SettingsCubit cubit) => cubit.state.getAmountInUnits(
        sendAll ? balance : amount,
        removeText: true,
        hideZero: true,
        removeEndZeros: true,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.title('    Amount'),
        const Gap(4),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: sendAll ? 0.5 : 1,
          child: IgnorePointer(
            ignoring: sendAll,
            child: Focus(
              focusNode: _focusNode,
              child: BBAmountInput(
                disabled: sendAll,
                value: amountStr,
                hint: 'Enter amount',
                onRightTap: () {
                  context.read<SettingsCubit>().toggleUnitsInSats();
                },
                isSats: isSats,
                onChanged: (txt) {
                  final aLen = amountStr.length;
                  final tLen = txt.length;

                  print('\n\n');
                  print('||--- $txt');

                  if ((tLen - aLen) > 1 || (aLen - tLen) > 1) {
                    return;
                  }

                  var clean = txt.replaceAll(',', '');
                  if (isSats)
                    clean = clean.replaceAll('.', '');
                  else if (!txt.contains('.')) {
                    return;
                  }
                  final amt =
                      context.read<SettingsCubit>().state.getSatsAmount(clean);
                  print('----- $amt');
                  context.read<SendCubit>().updateAmount(amt);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();

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
      hint: 'Enter private note',
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
    final watchOnly =
        context.select((WalletCubit cubit) => cubit.state.wallet!.watchOnly());

    final sending = context.select((SendCubit cubit) => cubit.state.sending);
    final showSend =
        context.select((SendCubit cubit) => cubit.state.showSendButton);
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
                      ? 'Confirm'
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
    final text = context
        .select((SendCubit cubit) => cubit.state.advancedOptionsButtonText());
    return BBButton.text(
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

    return BBButton.text(
      onPressed: () {
        AddressSelectionPopUp.openPopup(context);
      },
      label: 'Coin selection: $totalUTXOsSelected utxos',
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
    final amtStr = context
        .select((SettingsCubit cubit) => cubit.state.getAmountInUnits(amount));
    final amtFiat = context
        .select((SettingsCubit cubit) => cubit.state.calculatePrice(amount));
    final fee = context
        .select((SendCubit cubit) => cubit.state.psbtSignedFeeAmount ?? 0);
    final feeStr = context
        .select((SettingsCubit cubit) => cubit.state.getAmountInUnits(fee));
    final feeFiat = context
        .select((SettingsCubit cubit) => cubit.state.calculatePrice(fee));
    final fiatCurrency = context
        .select((SettingsCubit cubit) => cubit.state.currency?.shortName ?? '');

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
