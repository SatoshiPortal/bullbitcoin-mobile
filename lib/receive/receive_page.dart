import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_pkg/bull_bitcoin_api.dart';
import 'package:bb_mobile/_pkg/clipboard.dart';
import 'package:bb_mobile/_pkg/consts/keys.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/repository.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/_ui/bottom_sheet.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/_ui/headers.dart';
import 'package:bb_mobile/currency/amount_input.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/receive/bloc/receive_cubit.dart';
import 'package:bb_mobile/receive/bloc/state.dart';
import 'package:bb_mobile/receive/receive_page2.dart';
import 'package:bb_mobile/receive/wallet_select.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ReceivePage extends StatelessWidget {
  const ReceivePage({super.key, this.walletBloc});

  final WalletBloc? walletBloc;

  @override
  Widget build(BuildContext context) {
    final homeLayout = context.select((SettingsCubit _) => _.state.homeLayout);
    if (homeLayout == 0) return SelectReceiveWalletPage(walletBloc: walletBloc);
    return const ReceivePage2();
  }
}

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  late ReceiveCubit _cubit;
  @override
  void initState() {
    final wallet = context.read<SelectReceiveWalletStep>().state.walletBloc;
    if (wallet == null) return;

    _cubit = ReceiveCubit(
      walletBloc: wallet,
      walletAddress: locator<WalletAddress>(),
      walletTx: locator<WalletTx>(),
      hiveStorage: locator<HiveStorage>(),
      secureStorage: locator<SecureStorage>(),
      walletSensitiveRepository: locator<WalletSensitiveRepository>(),
      walletRepository: locator<WalletRepository>(),
      swapBoltz: locator<SwapBoltz>(),
      settingsCubit: locator<SettingsCubit>(),
      networkCubit: locator<NetworkCubit>(),
      currencyCubit: CurrencyCubit(
        hiveStorage: locator<HiveStorage>(),
        bbAPI: locator<BullBitcoinAPI>(),
        defaultCurrencyCubit: context.read<CurrencyCubit>(),
      ),
    );

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _cubit),
        BlocProvider.value(value: _cubit.currencyCubit),
      ],
      child: const _Screen(),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Gap(24),
            _WalletName(),
            ReceiveQRDisplay(),
            ReceiveDisplayAddress(),
            Gap(24),
            AddressDetails(),
            Actions(),
          ],
        ),
      ),
    );
  }
}

class AddressDetails extends StatelessWidget {
  const AddressDetails({super.key});

  @override
  Widget build(BuildContext context) {
    final label = context.select((ReceiveCubit x) => x.state.privateLabel);
    final amount = context.select((ReceiveCubit x) => x.state.savedInvoiceAmount);
    final description = context.select((ReceiveCubit x) => x.state.savedDescription);
    final amountStr = context.select(
      (CurrencyCubit cubit) => cubit.state.getAmountInUnits(
        amount,
        hideZero: true,
        isSats: true,
      ),
    );
    return Column(
      children: [
        if (label.isNotEmpty) ...[
          _DetailRow(
            text: label,
            onTap: () {
              RenameLabel.openPopUp(context);
            },
            title: 'Address Label',
          ),
        ] else ...[
          BBButton.textWithRightArrow(
            label: 'Address Label',
            onPressed: () {
              RenameLabel.openPopUp(context);
            },
          ),
        ],
        if (amount > 0) ...[
          _DetailRow(
            text: amountStr,
            onTap: () {
              CreateInvoice.openPopUp(context);
            },
            title: 'Amount Request',
          ),
        ],
        if (description.isNotEmpty) ...[
          _DetailRow(
            text: description,
            onTap: () {
              CreateInvoice.openPopUp(context);
            },
            title: 'Public Description',
          ),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.text, required this.onTap, required this.title});

  final String text;
  final String title;
  final Function onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(alignment: Alignment.centerLeft, child: BBText.title(title)),
        Row(
          children: [
            BBText.body(text, isBold: true),
            const Gap(4),
            IconButton(
              iconSize: 16,
              onPressed: () {
                onTap();
              },
              icon: FaIcon(
                FontAwesomeIcons.penToSquare,
                color: context.colour.secondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class Actions extends StatelessWidget {
  const Actions({super.key});

  @override
  Widget build(BuildContext context) {
    final showRequestButton = context.select((ReceiveCubit x) => x.state.showNewRequestButton());
    final errLoadingAddress = context.select((ReceiveCubit x) => x.state.errLoadingAddress);

    return Column(
      children: [
        if (showRequestButton)
          BBButton.textWithRightArrow(
            buttonKey: UIKeys.receiveRequestPaymentButton,
            label: 'Request a payment',
            onPressed: () {
              CreateInvoice.openPopUp(context);
            },
          ),
        BBButton.textWithRightArrow(
          buttonKey: UIKeys.receiveGenerateAddressButton,
          label: 'Generate a new address',
          onPressed: () {
            context.read<ReceiveCubit>().generateNewAddress();
          },
        ),
        BBText.errorSmall(errLoadingAddress),
      ],
    );
  }
}

class _WalletName extends StatelessWidget {
  const _WalletName();

  @override
  Widget build(BuildContext context) {
    final loading = context.select((ReceiveCubit x) => x.state.loadingAddress);

    final walletName = context.select((ReceiveCubit _) => _.state.walletBloc?.state.wallet?.name);

    final fingerprint = context
        .select((ReceiveCubit _) => _.state.walletBloc?.state.wallet?.sourceFingerprint ?? '');

    return AnimatedContainer(
      duration: 500.ms,
      child: Center(
        child: loading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  BBText.body('Waiting for sync to complete ...'),
                  Gap(32),
                  SizedBox(
                    height: 8,
                    width: 8,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              )
            : BBText.titleLarge(
                walletName ?? fingerprint,
              ),
      ),
    );
  }
}

class ReceiveQRDisplay extends StatelessWidget {
  const ReceiveQRDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final address = context.select((ReceiveCubit x) => x.state.getQRStr());

    return Center(
      child: GestureDetector(
        onTap: () async {
          if (locator.isRegistered<Clippboard>()) await locator<Clippboard>().copy(address);
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
        },
        child: ColoredBox(
          color: Colors.white,
          child: QrImageView(
            key: UIKeys.receiveQRDisplay,
            data: address,
          ),
        ),
      ),
    );
  }
}

class ReceiveDisplayAddress extends StatefulWidget {
  const ReceiveDisplayAddress({super.key});

  @override
  State<ReceiveDisplayAddress> createState() => _ReceiveDisplayAddressState();
}

class _ReceiveDisplayAddressState extends State<ReceiveDisplayAddress> {
  bool showToast = false;

  void _copyClicked() async {
    if (!mounted) return;
    setState(() {
      showToast = true;
    });
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      showToast = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final addressQr = context.select((ReceiveCubit x) => x.state.getQRStr());

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: !showToast
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 250,
                  child: BBText.body(
                    addressQr,
                    textAlign: TextAlign.center,
                    uiKey: UIKeys.receiveAddressDisplay,
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: IconButton(
                    onPressed: () async {
                      if (locator.isRegistered<Clippboard>())
                        await locator<Clippboard>().copy(addressQr);

                      _copyClicked();
                    },
                    iconSize: 30,
                    color: context.colour.secondary,
                    icon: const FaIcon(FontAwesomeIcons.copy),
                  ),
                ),
              ],
            )
          : const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: BBText.body('Address copied to clipboard'),
            ),
    );
  }
}

class CreateInvoice extends StatelessWidget {
  const CreateInvoice({super.key});

  static Future openPopUp(BuildContext context) async {
    final receiveCubit = context.read<ReceiveCubit>();
    final currencyCubit = context.read<CurrencyCubit>();
    // currencyCubit.reset();
    // currencyCubit.updateAmountDirect(receiveCubit.state.savedInvoiceAmount);
    // currencyCubit.updateAmount(receiveCubit.state.savedInvoiceAmount.toString());
    if (currencyCubit.state.amount > 0) currencyCubit.convertAmtOnCurrencyChange();

    return showBBBottomSheet(
      context: context,
      child: BlocProvider.value(
        value: receiveCubit,
        child: BlocProvider.value(
          value: currencyCubit,
          child: BlocListener<ReceiveCubit, ReceiveState>(
            listenWhen: (previous, current) =>
                previous.savedInvoiceAmount != current.savedInvoiceAmount ||
                previous.savedDescription != current.savedDescription,
            listener: (context, state) {
              context.pop();
            },
            child: const Padding(
              padding: EdgeInsets.all(30),
              child: CreateInvoice(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final description = context.select((ReceiveCubit _) => _.state.description);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BBHeader.popUpCenteredText(
          text: 'Request a Payment',
          onBack: () {
            context.read<ReceiveCubit>().clearInvoiceFields();
            context.pop();
          },
        ),
        const Gap(40),
        // const BBText.title('Amount'),
        const Gap(4),
        const EnterAmount(uiKey: UIKeys.receiveAmountField),
        const Gap(24),
        const BBText.title('   Public description'),
        const Gap(4),
        BBTextInput.big(
          uiKey: UIKeys.receiveDescriptionField,
          value: description,
          hint: 'Enter description',
          onChanged: (txt) {
            context.read<ReceiveCubit>().descriptionChanged(txt);
          },
        ),
        const Gap(40),
        BBButton.bigRed(
          buttonKey: UIKeys.receiveSavePaymentButton,
          label: 'Save',
          onPressed: () {
            context.read<ReceiveCubit>().saveFinalInvoiceClicked();
          },
        ),
        const Gap(40),
      ],
    );
  }
}

class RenameLabel extends StatelessWidget {
  const RenameLabel({super.key});

  static Future openPopUp(BuildContext context) async {
    final receiveCubit = context.read<ReceiveCubit>();

    return showBBBottomSheet(
      context: context,
      child: BlocProvider.value(
        value: receiveCubit,
        child: BlocListener<ReceiveCubit, ReceiveState>(
          listenWhen: (previous, current) =>
              previous.defaultAddress?.label != current.defaultAddress?.label,
          listener: (context, state) {
            context.pop();
          },
          child: const Padding(
            padding: EdgeInsets.all(30),
            child: RenameLabel(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = context.select((ReceiveCubit _) => _.state.privateLabel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBHeader.popUpCenteredText(text: 'Address Label'),
        const Gap(40),
        const BBText.title('Address Label (Optional)'),
        const Gap(4),
        BBTextInput.big(
          value: label,
          hint: 'Enter Private Label',
          onChanged: (txt) {
            context.read<ReceiveCubit>().privateLabelChanged(txt);
          },
        ),
        const Gap(40),
        BBButton.bigRed(
          label: 'Save',
          onPressed: () {
            context.read<ReceiveCubit>().saveDefaultAddressLabel();
          },
        ),
        const Gap(40),
      ],
    );
  }
}
