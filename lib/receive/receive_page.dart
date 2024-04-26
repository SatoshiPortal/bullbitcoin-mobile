import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_pkg/bull_bitcoin_api.dart';
import 'package:bb_mobile/_pkg/clipboard.dart';
import 'package:bb_mobile/_pkg/consts/keys.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/repository/sensitive_storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository/storage.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/bottom_sheet.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/controls.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/_ui/headers.dart';
import 'package:bb_mobile/_ui/warning.dart';
import 'package:bb_mobile/currency/amount_input.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/receive/bloc/receive_cubit.dart';
import 'package:bb_mobile/receive/bloc/state.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/swap/bloc/swap_cubit.dart';
import 'package:bb_mobile/swap/bloc/swap_state.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_event.dart';
import 'package:bb_mobile/swap/receive.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ReceivePage extends StatefulWidget {
  const ReceivePage({super.key, this.walletBloc});

  final WalletBloc? walletBloc;

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage> {
  late ReceiveCubit _receiveCubit;
  late CurrencyCubit _currencyCubit;
  late SwapCubit _swapCubit;

  @override
  void initState() {
    _swapCubit = SwapCubit(
      walletSensitiveRepository: locator<WalletSensitiveStorageRepository>(),
      swapBoltz: locator<SwapBoltz>(),
      walletTx: locator<WalletTx>(),
    );

    _currencyCubit = CurrencyCubit(
      hiveStorage: locator<HiveStorage>(),
      bbAPI: locator<BullBitcoinAPI>(),
      defaultCurrencyCubit: context.read<CurrencyCubit>(),
    );

    _receiveCubit = ReceiveCubit(
      walletAddress: locator<WalletAddress>(),
      walletsStorageRepository: locator<WalletsStorageRepository>(),
    );

    _receiveCubit.updateWalletType(
      ReceivePaymentNetwork.lightning,
      context.read<NetworkCubit>().state.testnet,
      onStart: true,
    );

    final network = context.read<NetworkCubit>().state.getBBNetwork();
    final walletBloc =
        widget.walletBloc ?? context.read<HomeCubit>().state.getMainInstantWallet(network);
    if (walletBloc == null) return;

    _receiveCubit.updateWalletBloc(walletBloc);

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final r = GoRouterState.of(context).uri.toString();
    print('Route:: ' + r);

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _receiveCubit),
        BlocProvider.value(value: _currencyCubit),
        BlocProvider.value(value: _swapCubit),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<ReceiveCubit, ReceiveState>(
            listenWhen: (previous, current) =>
                previous.updateAddressGap != current.updateAddressGap,
            listener: (context, state) {
              if (state.updateAddressGap == null) return;

              context.read<NetworkCubit>().updateStopGapAndSave(state.updateAddressGap!);
            },
          ),
          BlocListener<ReceiveCubit, ReceiveState>(
            listenWhen: (previous, current) => previous.switchToSecure != current.switchToSecure,
            listener: (context, state) {
              if (!state.switchToSecure) return;

              final network = context.read<NetworkCubit>().state.getBBNetwork();
              final secureWallet = context.read<HomeCubit>().state.getMainSecureWallet(network);
              if (secureWallet == null) return;
              context.read<ReceiveCubit>().updateWalletBloc(secureWallet);
              context.read<ReceiveCubit>().clearSwitch();
            },
          ),
          BlocListener<ReceiveCubit, ReceiveState>(
            listenWhen: (previous, current) => previous.switchToInstant != current.switchToInstant,
            listener: (context, state) {
              if (!state.switchToInstant) return;

              final network = context.read<NetworkCubit>().state.getBBNetwork();
              final instantWallet = context.read<HomeCubit>().state.getMainInstantWallet(network);
              if (instantWallet == null) return;
              context.read<ReceiveCubit>().updateWalletBloc(instantWallet);
              context.read<ReceiveCubit>().clearSwitch();
            },
          ),
          BlocListener<ReceiveCubit, ReceiveState>(
            listenWhen: (previous, current) => previous.defaultAddress != current.defaultAddress,
            listener: (context, state) {
              if (state.defaultAddress != null) return;

              context.read<SwapCubit>().clearSwapTx();
              context.read<CurrencyCubit>().reset();
            },
          ),
          BlocListener<SwapCubit, SwapState>(
            listenWhen: (previous, current) => previous.updatedWallet != current.updatedWallet,
            listener: (context, state) {
              final updatedWallet = state.updatedWallet;
              if (updatedWallet == null) return;

              context
                  .read<HomeCubit>()
                  .state
                  .getWalletBloc(
                    updatedWallet,
                  )
                  ?.add(
                    UpdateWallet(
                      updatedWallet,
                      updateTypes: [UpdateWalletTypes.swaps],
                    ),
                  );

              locator<WatchTxsBloc>().add(
                WatchWalletTxs(wallet: updatedWallet),
              );

              context.read<SwapCubit>().clearUpdatedWallet();
            },
          ),
        ],
        child: Scaffold(
          appBar: AppBar(
            flexibleSpace: const _ReceiveAppBar(),
            automaticallyImplyLeading: false,
          ),
          body: const _WalletProvider(child: _Screen()),
        ),
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    final swapTx = context.select((SwapCubit x) => x.state.swapTx);
    final isSupported = context.select((ReceiveCubit x) => x.state.isSupported());
    final showQR = context.select((ReceiveCubit x) => x.state.showQR(swapTx));

    final watchOnly = context.select((WalletBloc x) => x.state.wallet!.watchOnly());
    final mainWallet = context.select((ReceiveCubit x) => x.state.checkIfMainWalletSelected());

    final walletIsLiquid =
        context.select((WalletBloc x) => x.state.wallet!.baseWalletType == BaseWalletType.Liquid);
    final showWarning = context.select((SwapCubit x) => x.state.showWarning());
    final removeWarning = context.select((SettingsCubit x) => x.state.removeSwapWarnings);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showWarning && !removeWarning && !walletIsLiquid)
              const _Warnings()
            else ...[
              const Gap(32),
              const ReceiveWalletsDropDown(),
              const Gap(24),
              if (!watchOnly && mainWallet) ...[
                const SelectWalletType(),
                const Gap(48),
              ],
              if (!isSupported)
                const Column(
                  children: [
                    Center(child: BBText.error('Warning!')),
                    Center(child: Text('Chain-Chain swaps coming soon!')),
                  ],
                ),
              if (isSupported && showQR) ...[
                const ReceiveQR(),
                const Gap(8),
                const ReceiveAddress(),
                const Gap(8),
                const SwapFeesDetails(),
              ] else if (isSupported) ...[
                // const Gap(24),
                const CreateLightningInvoice(),
                const Gap(24),
                const SwapHistoryButton(),
              ],
              const Gap(48),
              if (isSupported) const WalletActions(),
              const Gap(32),
            ],
          ],
        ),
      ),
    );
  }
}

class ReceiveWalletsDropDown extends StatelessWidget {
  const ReceiveWalletsDropDown({super.key});

  @override
  Widget build(BuildContext context) {
    final network = context.select((NetworkCubit _) => _.state.getBBNetwork());
    final walletBlocs = context.select((HomeCubit _) => _.state.walletBlocsFromNetwork(network));
    final selectedWalletBloc = context.select((ReceiveCubit _) => _.state.walletBloc);

    final walletBloc = selectedWalletBloc ?? walletBlocs.first;

    return BBDropDown<WalletBloc>(
      items: {
        for (final wallet in walletBlocs)
          wallet: wallet.state.wallet!.name ?? wallet.state.wallet!.sourceFingerprint,
      },
      value: walletBloc,
      onChanged: (value) {
        context.read<ReceiveCubit>().updateWalletBloc(value);
      },
    );
  }
}

class SelectWalletType extends StatelessWidget {
  const SelectWalletType({super.key});

  @override
  Widget build(BuildContext context) {
    // final isTestnet = context.select((NetworkCubit _) => _.state.testnet);
    final paymentNetwork = context.select((ReceiveCubit x) => x.state.paymentNetwork);

    // if (!isTestnet) return const SizedBox.shrink();

    return BBSwitcher<ReceivePaymentNetwork>(
      value: paymentNetwork,
      items: const {
        ReceivePaymentNetwork.lightning: 'Lightning',
        ReceivePaymentNetwork.bitcoin: 'Bitcoin',
        ReceivePaymentNetwork.liquid: 'Liquid',
      },
      onChanged: (value) {
        if (paymentNetwork == ReceivePaymentNetwork.lightning)
          context.read<SwapCubit>().clearSwapTx();

        context.read<SwapCubit>().removeWarnings();

        final isTestnet = context.read<NetworkCubit>().state.testnet;
        context.read<ReceiveCubit>().updateWalletType(value, isTestnet);
      },
    );
  }
}

class _WalletProvider extends StatelessWidget {
  const _WalletProvider({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wallet = context.select((ReceiveCubit _) => _.state.walletBloc);

    if (wallet == null) return child;
    return BlocProvider.value(value: wallet, child: child);
  }
}

class _ReceiveAppBar extends StatelessWidget {
  const _ReceiveAppBar();

  @override
  Widget build(BuildContext context) {
    return BBAppBar(
      text: 'Receive bitcoin',
      onBack: () {
        context.pop();
      },
    );
  }
}

class _Warnings extends StatelessWidget {
  const _Warnings();

  Widget _buildLowAmtWarn() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BBText.titleLarge('Small amount warning', isRed: true),
        Gap(8),
        BBText.bodySmall(
          'You are about to receive less than 0.01 BTC as a Lightning Network payment and swap it to on-chain Bitcoin in your Secure Bitcoin Wallet.',
        ),
        Gap(8),
        BBText.bodySmall(
          'Only do this if you specifically want to add funds to your Secure Bitcoin Wallet.',
          isBold: true,
        ),
        Gap(24),
      ],
    );
  }

  Widget _buildHighFeesWarn({
    required int feePercentage,
    required int amt,
    required int fees,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.titleLarge('High fee warning', isRed: true),
        const Gap(8),
        const BBText.bodySmall(
          'You are about to pay over 3% in Bitcoin Network fees for this transaction.',
        ),
        const Gap(8),
        Row(
          children: [
            const BBText.bodySmall('Amount you receive: '),
            BBText.bodySmall('$amt sats', isBold: true),
          ],
        ),
        Row(
          children: [
            const BBText.bodySmall('Network fees: '),
            BBText.bodySmall('$fees sats', isBold: true),
          ],
        ),
        const Gap(24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final swapTx = context.select((SwapCubit x) => x.state.swapTx);
    if (swapTx == null) return const SizedBox.shrink();

    final errLowAmt = context.select((SwapCubit x) => x.state.swapTx!.smallAmt());
    final errHighFees = context.select((SwapCubit x) => x.state.swapTx!.highFees());

    return WarningContainer(
      children: [
        const Gap(24),
        if (errLowAmt) _buildLowAmtWarn(),
        if (errHighFees != null)
          _buildHighFeesWarn(
            feePercentage: errHighFees,
            amt: swapTx.outAmount,
            fees: swapTx.totalFees() ?? 0,
          ),
        const Row(
          children: [
            Icon(FontAwesomeIcons.lightbulb, size: 32),
            Gap(8),
            Expanded(child: BBText.titleLarge('Suggestions', isBold: true)),
          ],
        ),
        const Gap(24),
        const BBText.bodySmall('''
1. Use the Instant Payment Wallet instead to receive payments below 0.01 BTC.

2. If you want to add funds to your Secure Bitcoin Wallet from an external Lightning Wallet, send a larger amount. We recommend at minimum 0.01 BTC.

3. It is more economical to make fewer swaps of larger amounts than to make many swaps of smaller amounts'''),
        const Gap(8),
        const _RemoveWarningMessage(),
        const Gap(24),
        Center(
          child: BBButton.big(
            leftIcon: Icons.send_outlined,
            label: 'Continue anyways',
            onPressed: () {
              context.read<SwapCubit>().removeWarnings();
            },
          ),
        ),
      ],
    );
  }
}

class _RemoveWarningMessage extends StatelessWidget {
  const _RemoveWarningMessage();

  @override
  Widget build(BuildContext context) {
    final removeWarning = context.select((SettingsCubit x) => x.state.removeSwapWarnings);

    return Row(
      children: [
        Checkbox(
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          value: removeWarning,
          onChanged: (checked) {
            if (checked != null) context.read<SettingsCubit>().changeSwapWarnings(checked);
          },
          side: BorderSide(width: 2, color: context.colour.surface),
          // fillColor: context.colour.surface,
        ),
        const Gap(2),
        BBButton.text(
          label: "Don't show this warning again",
          fontSize: 12,
          onPressed: () {
            context.read<SettingsCubit>().changeSwapWarnings(true);
          },
        ),
      ],
    );
  }
}

class WalletActions extends StatelessWidget {
  const WalletActions({super.key});

  @override
  Widget build(BuildContext context) {
    final isLn = context.select((ReceiveCubit x) => x.state.isLn());
    if (isLn) return const SizedBox.shrink();

    final swap = context.select((SwapCubit _) => _.state.swapTx);
    final show = context.select((ReceiveCubit _) => _.state.showQR(swap));
    if (!show) return const SizedBox.shrink();

    final showRequestButton = context.select((ReceiveCubit x) => x.state.showNewRequestButton());
    final errLoadingAddress = context.select((ReceiveCubit x) => x.state.errLoadingAddress);

    return Column(
      children: [
        const CheckForPaymentsButton(),
        const Gap(8),
        const AddLabelButton(),
        const Gap(8),
        if (showRequestButton)
          BBButton.big(
            buttonKey: UIKeys.receiveRequestPaymentButton,
            label: 'Request payment',
            leftSvgAsset: 'assets/request-payment.svg',
            onPressed: () {
              CreateInvoice.openPopUp(context);
            },
          ),
        const Gap(8),
        BBButton.big(
          buttonKey: UIKeys.receiveGenerateAddressButton,
          label: 'Get new address',
          leftSvgAsset: 'assets/new-address.svg',
          onPressed: () {
            context.read<CurrencyCubit>().updateAmountDirect(0);
            final paymentNetwork = context.read<ReceiveCubit>().state.paymentNetwork;
            if (paymentNetwork == ReceivePaymentNetwork.lightning)
              context.read<SwapCubit>().clearSwapTx();

            context.read<ReceiveCubit>().generateNewAddress();
          },
        ),
        BBText.errorSmall(errLoadingAddress),
      ],
    );
  }
}

class CreateLightningInvoice extends StatelessWidget {
  const CreateLightningInvoice({super.key});

  @override
  Widget build(BuildContext context) {
    final description = context.select((ReceiveCubit _) => _.state.description);
    final err = context.select((SwapCubit _) => _.state.errCreatingSwapInv);
    final creatingInv = context.select((SwapCubit _) => _.state.generatingSwapInv);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.title(' Amount (required)'),
        const Gap(4),
        const EnterAmount2(),
        const Gap(24),
        const BBText.title(' Description'),
        const Gap(4),
        BBTextInput.big(
          uiKey: UIKeys.receiveDescriptionField,
          value: description,
          hint: 'Enter description',
          onChanged: (txt) {
            context.read<ReceiveCubit>().descriptionChanged(txt);
          },
        ),
        const Gap(48),
        Center(
          child: BBButton.big(
            // leftIcon: FontAwesomeIcons.receipt,
            leftSvgAsset: 'assets/request-payment.svg',
            buttonKey: UIKeys.receiveSavePaymentButton,
            loading: creatingInv,
            label: 'Create Invoice',
            loadingText: 'Creating Invoice',
            onPressed: () async {
              final amt = context.read<CurrencyCubit>().state.amount;
              final wallet = context.read<ReceiveCubit>().state.walletBloc!.state.wallet!;
              final walletIsLiquid = wallet.baseWalletType == BaseWalletType.Liquid;
              final label = context.read<ReceiveCubit>().state.description;
              final isTestnet = context.read<NetworkCubit>().state.testnet;
              final networkUrl = !walletIsLiquid
                  ? context.read<NetworkCubit>().state.getNetworkUrl()
                  : context.read<NetworkCubit>().state.getLiquidNetworkUrl();

              context.read<SwapCubit>().createRevSwapForReceive(
                    amount: amt,
                    wallet: wallet,
                    label: label,
                    isTestnet: isTestnet,
                    networkUrl: networkUrl,
                  );
            },
          ),
        ),
        const Gap(16),
        BBText.errorSmall(err, textAlign: TextAlign.center),
        const Gap(40),
      ],
    );
  }
}

class SwapFeesDetails extends StatelessWidget {
  const SwapFeesDetails({super.key});

  @override
  Widget build(BuildContext context) {
    final swapTx = context.select((SwapCubit _) => _.state.swapTx);
    if (swapTx == null) return const SizedBox.shrink();

    final isLn = context.select((ReceiveCubit x) => x.state.isLn());
    if (!isLn) return const SizedBox.shrink();

    final totalFees = swapTx.totalFees() ?? 0;
    final fees =
        context.select((CurrencyCubit x) => x.state.getAmountInUnits(totalFees, removeText: true));
    final units = context.select(
      (CurrencyCubit cubit) => cubit.state.getUnitString(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BBText.bodySmall('Total fees:\n$fees $units'),
        const Gap(16),
      ],
    );
  }
}

class ReceiveQR extends StatelessWidget {
  const ReceiveQR({super.key});

  @override
  Widget build(BuildContext context) {
    final swapTx = context.select((SwapCubit x) => x.state.swapTx);
    final address = context.select((ReceiveCubit x) => x.state.getQRStr(swapTx: swapTx));

    return ReceiveQRDisplay(address: address);
  }
}

class ReceiveQRDisplay extends StatelessWidget {
  const ReceiveQRDisplay({super.key, required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onLongPress: () async {
          if (locator.isRegistered<Clippboard>()) await locator<Clippboard>().copy(address);

          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
        },
        child: Column(
          children: [
            const BBText.bodySmall('long press to copy address'),
            ColoredBox(
              color: Colors.white,
              child: QrImageView(
                key: UIKeys.receiveQRDisplay,
                data: address,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReceiveAddress extends StatelessWidget {
  const ReceiveAddress({super.key});

  @override
  Widget build(BuildContext context) {
    final swapTx = context.select((SwapCubit x) => x.state.swapTx);
    final addressQr = context.select((ReceiveCubit x) => x.state.getQRStr(swapTx: swapTx));

    return ReceiveDisplayAddress(addressQr: addressQr);
  }
}

class ReceiveDisplayAddress extends StatefulWidget {
  const ReceiveDisplayAddress({
    super.key,
    required this.addressQr,
    this.minify = true,
    this.fontSize,
  });

  final String addressQr;
  final double? fontSize;
  final bool minify;

  @override
  State<ReceiveDisplayAddress> createState() => _ReceiveDisplayAddressState();
}

class _ReceiveDisplayAddressState extends State<ReceiveDisplayAddress> {
  bool showToast = false;

  @override
  Widget build(BuildContext context) {
    final address = widget.minify
        ? widget.addressQr.length < 14
            ? widget.addressQr
            : widget.addressQr.substring(0, 10) +
                ' ... ' +
                widget.addressQr.substring(widget.addressQr.length - 5)
        : widget.addressQr;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: !showToast
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 250,
                  child: BBText.body(
                    address,
                    textAlign: TextAlign.center,
                    uiKey: UIKeys.receiveAddressDisplay,
                    fontSize: widget.fontSize,
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
            context.read<CurrencyCubit>().reset();

            context.pop();
          },
        ),
        const Gap(40),
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
        BBButton.big(
          buttonKey: UIKeys.receiveSavePaymentButton,
          label: 'Save',
          onPressed: () {
            final amt = context.read<CurrencyCubit>().state.amount;
            context.read<ReceiveCubit>().saveFinalInvoiceClicked(amt);
          },
        ),
        const Gap(40),
      ],
    );
  }
}

class CheckForPaymentsButton extends StatelessWidget {
  const CheckForPaymentsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.big(
      label: 'Check for payment',
      // leftIcon: FontAwesomeIcons.arrowRotateLeft,
      leftSvgAsset: 'assets/refresh.svg',
      onPressed: () {},
    );
  }
}

class AddLabelButton extends StatelessWidget {
  const AddLabelButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.big(
      label: 'Add address label',
      // leftIcon: FontAwesomeIcons.penToSquare,
      leftSvgAsset: 'assets/edit.svg',
      onPressed: () {
        AddLabelPopUp.openPopUp(context);
      },
    );
  }
}

class AddLabelPopUp extends StatelessWidget {
  const AddLabelPopUp({super.key});

  static Future openPopUp(BuildContext context) async {
    final receive = context.read<ReceiveCubit>();
    return showBBBottomSheet(
      context: context,
      child: BlocProvider.value(
        value: receive,
        child: const Padding(
          padding: EdgeInsets.all(30),
          child: AddLabelPopUp(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = context.select((ReceiveCubit x) => x.state.description);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BBHeader.popUpCenteredText(
          text: 'Add Label',
          isLeft: true,
          onBack: () {
            context.pop();
          },
        ),
        const Gap(24),
        BBTextInput.big(
          hint: 'Enter label',
          value: value,
          onChanged: (txt) {
            context.read<ReceiveCubit>().descriptionChanged(txt);
          },
        ),
        const Gap(40),
        Center(
          child: BBButton.big(
            label: 'Save',
            onPressed: () {
              context.read<ReceiveCubit>().saveDefaultAddressLabel();
            },
          ),
        ),
        const Gap(40),
      ],
    );
  }
}
