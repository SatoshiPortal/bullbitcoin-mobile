import 'package:bb_mobile/_model/swap.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_pkg/bull_bitcoin_api.dart';
import 'package:bb_mobile/_pkg/clipboard.dart';
import 'package:bb_mobile/_pkg/consts/keys.dart';
import 'package:bb_mobile/_pkg/payjoin/manager.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/_repository/app_wallets_repository.dart';
import 'package:bb_mobile/_repository/network_repository.dart';
import 'package:bb_mobile/_repository/wallet/sensitive_wallet_storage.dart';
import 'package:bb_mobile/_repository/wallet/wallet_storage.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/controls.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/_ui/warning.dart';
import 'package:bb_mobile/currency/amount_input.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_bloc.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_bloc.dart';
import 'package:bb_mobile/receive/bloc/receive_cubit.dart';
import 'package:bb_mobile/receive/listeners.dart';
import 'package:bb_mobile/settings/bloc/lighting_cubit.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/swap/create_swap_bloc/swap_cubit.dart';
import 'package:bb_mobile/swap/ui_swapwidget/wallet_dropdown.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:boltz_dart/boltz_dart.dart' as boltz;
import 'package:boltz_dart/boltz_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

const btcAddress =
    'tb1qlmj5w2upndhhc9rgd9jg07vcuafg3jydef7uvz'; // Vegeta wallet
const lqAddress =
    'tlq1qqd8f92dfedpvsydxxk54l8glwa5m8e84ygqz7n5dgyujp37v3n60pjzfrc2xu4a9fla6snzgznn9tjpwc99d7kn2s472sw2la';

const btcMainnetAddress = 'bc1qrh2s82ec3998qeusuy007u6r3z0e4s2xg3s63z';
const lqMainnetAddress =
    'lq1qq23h89g7u7ngp2n7p7tvek7n97dckyfyu89e3j875rqz35u8rd9tmy8fss0q7zke3lzj80834zl6t72pw2khqz0fkf6hnswne';

class ReceivePage extends StatefulWidget {
  const ReceivePage({super.key, this.wallet});

  final String? wallet;

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage> {
  late ReceiveCubit _receiveCubit;
  late CurrencyCubit _currencyCubit;
  late CreateSwapCubit _swapCubit;

  @override
  void initState() {
    // print('-----2 - ${DateTime.now()}');
    // _swapCubit = CreateSwapCubit(
    //   walletSensitiveRepository: locator<WalletSensitiveStorageRepository>(),
    //   swapBoltz: locator<SwapBoltz>(),
    //   walletTx: locator<WalletTx>(),
    //   appWalletsRepository: locator<AppWalletsRepository>(),
    //   // homeCubit: context.read<HomeBloc>(),
    //   watchTxsBloc: context.read<WatchTxsBloc>(),
    //   networkRepository: context.read<NetworkRepository>(),
    //   // networkCubit: context.read<NetworkBloc>(),
    // )..fetchFees(context.read<NetworkBloc>().state.networkData.testnet);
    // print('-----3 - ${DateTime.now()}');

    // _currencyCubit = CurrencyCubit(
    //   hiveStorage: locator<HiveStorage>(),
    //   bbAPI: locator<BullBitcoinAPI>(),
    //   defaultCurrencyCubit: context.read<CurrencyCubit>(),
    // );
    // print('-----4 - ${DateTime.now()}');

    // final w = widget.wallet != null
    //     ? context.read<AppWalletsRepository>().getWalletById(widget.wallet!)
    //     : null;
    // print('-----5 - ${DateTime.now()}');

    // _receiveCubit = ReceiveCubit(
    //   walletAddress: locator<WalletAddress>(),
    //   walletsStorageRepository: locator<WalletsStorageRepository>(),
    //   appWalletsRepository: locator<AppWalletsRepository>(),
    //   wallet: w,

    //   // walletBloc:
    //   // widget.wallet != null ? createWalletBloc(widget.wallet!) : null,
    //   payjoinManager: locator<PayjoinManager>(),
    // );
    // print('-----6 - ${DateTime.now()}');

    // final network = context.read<NetworkRepository>().getBBNetwork;
    // print('-----7 - ${DateTime.now()}');

    // final wallet =
    //     w ?? context.read<AppWalletsRepository>().getMainInstantWallet(network);
    // print('-----8 - ${DateTime.now()}');

    // if (wallet!.isLiquid()) {
    //   _receiveCubit.updateWalletType(
    //     PaymentNetwork.lightning,
    //     context.read<NetworkBloc>().state.networkData.testnet,
    //     onStart: true,
    //   );
    // } else {
    //   _receiveCubit.updateWalletType(
    //     PaymentNetwork.bitcoin,
    //     context.read<NetworkBloc>().state.networkData.testnet,
    //     onStart: true,
    //   );
    // }
    // print('-----10 - ${DateTime.now()}');

    // _receiveCubit.updateWallet(wallet);
    // print('-----11 - ${DateTime.now()}');

    super.initState();
  }

  Future _setupBlocs() async {
    print('-----2 - ${DateTime.now()}');
    _swapCubit = CreateSwapCubit(
      walletSensitiveRepository: locator<WalletSensitiveStorageRepository>(),
      swapBoltz: locator<SwapBoltz>(),
      walletTx: locator<WalletTx>(),
      appWalletsRepository: locator<AppWalletsRepository>(),
      // homeCubit: context.read<HomeBloc>(),
      watchTxsBloc: context.read<WatchTxsBloc>(),
      networkRepository: context.read<NetworkRepository>(),
      // networkCubit: context.read<NetworkBloc>(),
    )..fetchFees(context.read<NetworkBloc>().state.networkData.testnet);
    print('-----3 - ${DateTime.now()}');

    _currencyCubit = CurrencyCubit(
      hiveStorage: locator<HiveStorage>(),
      bbAPI: locator<BullBitcoinAPI>(),
      defaultCurrencyCubit: context.read<CurrencyCubit>(),
    );
    print('-----4 - ${DateTime.now()}');

    final w = widget.wallet != null
        ? context.read<AppWalletsRepository>().getWalletById(widget.wallet!)
        : null;
    print('-----5 - ${DateTime.now()}');

    _receiveCubit = ReceiveCubit(
      walletAddress: locator<WalletAddress>(),
      walletsStorageRepository: locator<WalletsStorageRepository>(),
      appWalletsRepository: locator<AppWalletsRepository>(),
      wallet: w,

      // walletBloc:
      // widget.wallet != null ? createWalletBloc(widget.wallet!) : null,
      payjoinManager: locator<PayjoinManager>(),
    );
    print('-----6 - ${DateTime.now()}');

    final network = context.read<NetworkRepository>().getBBNetwork;
    print('-----7 - ${DateTime.now()}');

    final wallet =
        w ?? context.read<AppWalletsRepository>().getMainInstantWallet(network);
    print('-----8 - ${DateTime.now()}');

    if (wallet!.isLiquid()) {
      _receiveCubit.updateWalletType(
        PaymentNetwork.lightning,
        context.read<NetworkBloc>().state.networkData.testnet,
        onStart: true,
      );
    } else {
      _receiveCubit.updateWalletType(
        PaymentNetwork.bitcoin,
        context.read<NetworkBloc>().state.networkData.testnet,
        onStart: true,
      );
    }
    print('-----10 - ${DateTime.now()}');

    _receiveCubit.updateWallet(wallet);
    print('-----11 - ${DateTime.now()}');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _setupBlocs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }

        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: _receiveCubit),
            BlocProvider.value(value: _currencyCubit),
            BlocProvider.value(value: _swapCubit),
          ],
          child: ReceiveListeners(
            child: Scaffold(
              appBar: AppBar(
                flexibleSpace: const _ReceiveAppBar(),
                automaticallyImplyLeading: false,
              ),
              body: _WalletProvider(
                child: const _Screen().animate(delay: 400.ms).fadeIn(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    final swapTx = context.select((CreateSwapCubit x) => x.state.swapTx);
    final isChainSwap =
        context.select((ReceiveCubit x) => x.state.isChainSwap());

    final showQR = context.select(
      (ReceiveCubit x) => x.state.showQR(swapTx, isChainSwap: isChainSwap),
    );
    final loadingAddress =
        context.select((ReceiveCubit x) => x.state.loadingAddress);

    final watchOnly =
        context.select((WalletBloc x) => x.state.wallet.watchOnly());
    final mainWallet =
        context.select((ReceiveCubit x) => x.state.checkIfMainWalletSelected());
    context.select((WalletBloc x) => x.state.wallet);

    final walletIsLiquid = context.select(
      (WalletBloc x) => x.state.wallet.isLiquid(),
    );
    final showWarning =
        context.select((CreateSwapCubit x) => x.state.showWarning());
    final removeWarning =
        context.select((SettingsCubit x) => x.state.removeSwapWarnings);

    final paymentNetwork =
        context.select((ReceiveCubit x) => x.state.paymentNetwork);
    final formSubmitted =
        context.select((ReceiveCubit x) => x.state.receiveFormSubmitted);
    final shouldShowForm = paymentNetwork == PaymentNetwork.bitcoin ||
        paymentNetwork == PaymentNetwork.liquid;

    final description = context.select((ReceiveCubit _) => _.state.description);
    final shouldShownDescription =
        (paymentNetwork == PaymentNetwork.lightning &&
                description.isNotEmpty) ||
            (paymentNetwork != PaymentNetwork.lightning && formSubmitted);

    final addressQr =
        context.select((ReceiveCubit x) => x.state.getQRStr(swapTx: swapTx));
    // ****************
    // BEGIN: ON CHAIN
    // ****************

    /*
    final swapFees = swapTx?.totalFees() ?? 0;
    final fee = swapFees; // TODO: Sender fee is managed by sender;
    final feeStr = context
        .select((CurrencyCubit cubit) => cubit.state.getAmountInUnits(fee));

    final currency =
        context.select((CurrencyCubit _) => _.state.defaultFiatCurrency);
    final feeFiat = context.select(
      (NetworkCubit cubit) => cubit.state.calculatePrice(fee, currency),
    );

    final fiatCurrency = context.select(
      (CurrencyCubit cubit) => cubit.state.defaultFiatCurrency?.shortName ?? '',
    );
    */

    // **************
    // END: ON CHAIN
    // **************

    if (showWarning && !removeWarning && !walletIsLiquid) {
      return const _Warnings();
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Gap(32),
            const ReceiveWalletsDropDown(),
            const Gap(24),
            if (!watchOnly && mainWallet) ...[
              const SelectWalletType(),
              const Gap(16),
            ],
            if (isChainSwap == true && swapTx == null) const ChainSwapForm(),
            if (isChainSwap == true && swapTx != null) ...[
              const ChainSwapDisplayReceive(),
              const Gap(16),
              const SwapFeesDetails(),
            ],
            if (isChainSwap == false && showQR) ...[
              if (loadingAddress)
                const Center(child: CircularProgressIndicator())
              else
                Column(
                  children: [
                    const ReceiveQR(),
                    const Gap(8),
                    ReceiveAddress(
                      swapTx: swapTx,
                      addressQr: addressQr,
                    ),
                  ],
                ),
              const Gap(8),
              if (shouldShowForm) const BitcoinReceiveForm(),
              if (paymentNetwork == PaymentNetwork.lightning || formSubmitted)
                const RequestedAmount(),
              if (shouldShownDescription) const Gap(8),
              if (shouldShownDescription) const PaymentDescription(),
              const Gap(16),
              const SwapFeesDetails(),
            ] else if (isChainSwap == false) ...[
              const CreateLightningInvoice(),
            ],
            const Gap(2),
            if (isChainSwap == false) const WalletActions(),
            const Gap(32),
          ],
        ),
      ),
    );
  }
}

class ReceiveWalletsDropDown extends StatefulWidget {
  const ReceiveWalletsDropDown({super.key});

  @override
  State<ReceiveWalletsDropDown> createState() => _ReceiveWalletsDropDownState();
}

class _ReceiveWalletsDropDownState extends State<ReceiveWalletsDropDown> {
  List<Wallet> wallets = [];

  @override
  void initState() {
    final network = context.read<NetworkRepository>().getBBNetwork;
    wallets = context.read<AppWalletsRepository>().walletsFromNetwork(network);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final oneWallet = context.select((ReceiveCubit _) => _.state.oneWallet);
    // final network = context.select((NetworkCubit _) => _.state.getBBNetwork());
    // final walletBlocs = context
    //     .select((HomeBloc _) => _.state.walletBlocsFromNetwork(network));
    final selectedWallet = context.select((ReceiveCubit _) => _.state.wallet);

    // final walletBloc = selectedWalletBloc ?? walletBlocs.first;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: oneWallet ? 0.5 : 1,
      child: IgnorePointer(
        ignoring: oneWallet,
        child: WalletDropDown(
          items: wallets,
          // walletBlocs.map((wb) => wb.state.wallet).toList(),
          onChanged: (wallet) {
            // final blocs = wallets.where((_) => _ == wallet).toList();
            if (wallets.isNotEmpty) {
              context.read<CreateSwapCubit>().removeWarnings();
              context.read<ReceiveCubit>().updateWallet(wallets[0]);
            }
          },
          value: selectedWallet ?? wallets[0],
        ),

        /*
        child: BBDropDown<WalletBloc>(
          walletSelector: true,
          items: {
            for (final wallet in walletBlocs)
              wallet: (
                label: wallet.state.wallet!.name ??
                    wallet.state.wallet!.sourceFingerprint,
                enabled: true,
                imagePath: wallet.state.wallet!.baseWalletType.getImage,
              ),
          },
          value: walletBloc,
          onChanged: (value) {
            context.read<CreateSwapCubit>().removeWarnings();
            context.read<ReceiveCubit>().updateWalletBloc(value);
          },
        ),
        */
      ),
    );
  }
}

class SelectWalletType extends StatelessWidget {
  const SelectWalletType({super.key});

  @override
  Widget build(BuildContext context) {
    // final isTestnet = context.select((NetworkCubit _) => _.state.testnet);
    final swapTx = context.select((CreateSwapCubit x) => x.state.swapTx);
    final paymentNetwork =
        context.select((ReceiveCubit x) => x.state.paymentNetwork);

    final btcAllowed = context.select(
      (ReceiveCubit _) => _.state.allowedSwitch(PaymentNetwork.bitcoin),
    );

    final liqAllowed = context.select(
      (ReceiveCubit _) => _.state.allowedSwitch(PaymentNetwork.liquid),
    );

    // if (!isTestnet) return const SizedBox.shrink();

    return BBSwitcher<PaymentNetwork>(
      value: paymentNetwork,
      items: {
        PaymentNetwork.lightning: 'Lightning',
        if (btcAllowed) PaymentNetwork.bitcoin: 'Bitcoin',
        if (liqAllowed) PaymentNetwork.liquid: 'Liquid',
      },
      onChanged: (value) {
        if (paymentNetwork == PaymentNetwork.lightning ||
            swapTx?.isChainSwap() == true) {
          context.read<CreateSwapCubit>().clearSwapTx();
        }

        context.read<CurrencyCubit>().reset();
        context.read<CurrencyCubit>().updateAmountDirect(0);
        context.read<CreateSwapCubit>().removeWarnings();

        final isTestnet = context.read<NetworkBloc>().state.networkData.testnet;
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
    final wallet = context.select((ReceiveCubit _) => _.state.wallet);

    if (wallet == null) return child;
    return BlocProvider.value(
      value: createOrRetreiveWalletBloc(wallet.id),
      child: child,
    );
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

  Widget buildLowAmtWarn(bool onChain) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.titleLarge('Small amount warning', isRed: true),
        const Gap(8),
        BBText.bodySmall(
          'You are about to receive less than 0.01 BTC as ${onChain == true ? 'Onchain swap' : 'a Lightning Network payment'} and swap it to on-chain Bitcoin in your Secure Bitcoin Wallet.',
        ),
        const Gap(8),
        const BBText.bodySmall(
          'Only do this if you specifically want to add funds to your Secure Bitcoin Wallet.',
          isBold: true,
        ),
        const Gap(24),
      ],
    );
  }

  Widget buildHighFeesWarn({
    required double feePercentage,
    required int amt,
    required int fees,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.titleLarge('High fee warning', isRed: true),
        const Gap(8),
        Row(
          children: [
            const BBText.bodySmall('You are about to pay over '),
            BBText.bodySmall(
              '${feePercentage.toStringAsFixed(2)}% ',
              isBold: true,
            ),
          ],
        ),
        const BBText.bodySmall(
          'in Bitcoin Network fees for this transaction.',
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
    final swapTx = context.select((CreateSwapCubit x) => x.state.swapTx);
    if (swapTx == null) return const SizedBox.shrink();

    final errLowAmt =
        context.select((CreateSwapCubit x) => x.state.swapTx!.smallAmt());
    final errHighFees =
        context.select((CreateSwapCubit x) => x.state.swapTx!.highFees());

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WarningContainer(
              children: [
                const Gap(24),
                if (errLowAmt) buildLowAmtWarn(swapTx.isChainSwap()),
                if (errHighFees != null)
                  buildHighFeesWarn(
                    feePercentage: errHighFees,
                    amt: swapTx.outAmount,
                    fees: swapTx.totalFees() ?? 0,
                  ),
                const Row(
                  children: [
                    Icon(FontAwesomeIcons.lightbulb, size: 32),
                    Gap(8),
                    Expanded(
                      child: BBText.titleLarge('Suggestions', isBold: true),
                    ),
                  ],
                ),
                const Gap(24),
                const BBText.bodySmall('''
1. Use the Instant Payment Wallet instead to receive payments below 0.01 BTC.

2. If you want to add funds to your Secure Bitcoin Wallet from an external Lightning Wallet, send a larger amount. We recommend at minimum 0.01 BTC.

3. It is more economical to make fewer swaps of larger amounts than to make many swaps of smaller amounts'''),
                // const Gap(8),
                // const _RemoveWarningMessage(),
                const Gap(24),
                Center(
                  child: BBButton.big(
                    leftIcon: Icons.send_outlined,
                    label: 'Continue anyways',
                    onPressed: () {
                      context.read<CreateSwapCubit>().removeWarnings();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// class _RemoveWarningMessage extends StatelessWidget {
//   const _RemoveWarningMessage();

//   @override
//   Widget build(BuildContext context) {
//     final removeWarning =
//         context.select((SettingsCubit x) => x.state.removeSwapWarnings);

//     return Row(
//       children: [
//         Checkbox(
//           materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
//           visualDensity: VisualDensity.compact,
//           value: removeWarning,
//           onChanged: (checked) {
//             if (checked != null)
//               context.read<SettingsCubit>().changeSwapWarnings(checked);
//           },
//           side: BorderSide(width: 2, color: context.colour.surface),
//           // fillColor: context.colour.surface,
//         ),
//         const Gap(2),
//         BBButton.text(
//           label: "Don't show this warning again",
//           fontSize: 12,
//           onPressed: () {
//             context.read<SettingsCubit>().changeSwapWarnings(true);
//           },
//         ),
//       ],
//     );
//   }
// }

class WalletActions extends StatelessWidget {
  const WalletActions({super.key});

  @override
  Widget build(BuildContext context) {
    final isLn = context.select((ReceiveCubit x) => x.state.isLn());
    if (isLn) return const SizedBox.shrink();

    final swap = context.select((CreateSwapCubit _) => _.state.swapTx);
    final show = context.select((ReceiveCubit _) => _.state.showQR(swap));
    if (!show) return const SizedBox.shrink();

    final errLoadingAddress =
        context.select((ReceiveCubit x) => x.state.errLoadingAddress);

    return Column(
      children: [
        // const CheckForPaymentsButton(),
        // const Gap(8),
        // const AddLabelButton(),
        // const Gap(8),
        // if (showRequestButton)
        //   BBButton.big(
        //     buttonKey: UIKeys.receiveRequestPaymentButton,
        //     label: 'Request payment',
        //     leftSvgAsset: 'assets/request-payment.svg',
        //     onPressed: () {
        //       CreateInvoice.openPopUp(context);
        //     },
        //   ),
        const _SaveLabelButton(),
        const Gap(8),
        BBButton.big(
          buttonKey: UIKeys.receiveGenerateAddressButton,
          label: 'Get new address',
          leftSvgAsset: 'assets/new-address.svg',
          onPressed: () {
            context.read<CurrencyCubit>().updateAmountDirect(0);
            final paymentNetwork =
                context.read<ReceiveCubit>().state.paymentNetwork;
            if (paymentNetwork == PaymentNetwork.lightning) {
              context.read<CreateSwapCubit>().clearSwapTx();
            }

            context.read<ReceiveCubit>().generateNewAddress();
          },
        ),
        BBText.errorSmall(errLoadingAddress),
      ],
    );
  }
}

class _SaveLabelButton extends StatelessWidget {
  const _SaveLabelButton();

  @override
  Widget build(BuildContext context) {
    final saving = context.select((ReceiveCubit x) => x.state.savingLabel);
    final saved = context.select((ReceiveCubit x) => x.state.labelSaved);
    return BBButton.big(
      leftIcon: saved ? Icons.check : Icons.save_as,
      label: saved ? 'Label Saved' : 'Save Label',
      loading: saving,
      disabled: saving || saved,
      loadingText: 'Saving...',
      onPressed: () {
        context.read<ReceiveCubit>().saveAddrressLabel();
      },
    );
  }
}

class ChainSwapDisplayReceive extends StatelessWidget {
  const ChainSwapDisplayReceive({super.key});

  @override
  Widget build(BuildContext context) {
    final swapTx = context.select((CreateSwapCubit x) => x.state.swapTx);
    if (swapTx == null) return const SizedBox.shrink();

    final amount = swapTx.outAmount / 100000000.0;
    final isTestnet =
        context.select((NetworkBloc x) => x.state.networkData.testnet);
    final bip21Address = context.select(
      (ReceiveCubit x) => x.state.getAddressWithAmountAndLabel(
        amount,
        swapTx.isLiquid(),
        swapTx: swapTx,
        isTestnet: isTestnet,
      ),
    );

    return Column(
      children: [
        ReceiveQRDisplay(address: bip21Address),
        const Gap(3),
        ReceiveDisplayAddress(addressQr: bip21Address),
      ],
    );
  }
}

class ChainSwapForm extends StatelessWidget {
  const ChainSwapForm({super.key});

  @override
  Widget build(BuildContext context) {
    final description = context.select((ReceiveCubit _) => _.state.description);
    context.select((CreateSwapCubit x) => x.state.allFees);
    context.select((CurrencyCubit x) => x.state.amount);

    context.select(
      (ReceiveCubit x) => x.state.wallet?.isLiquid(),
    );
    final err = context.select((CreateSwapCubit _) => _.state.err());

    final generatingInv = context
        .select((CreateSwapCubit cubit) => cubit.state.generatingSwapInv);
    final sending = generatingInv;

    final darkMode = context.select(
      (Lighting x) => x.state.currentTheme(context) == ThemeMode.dark,
    );

    final swapIcon = darkMode
        ? 'assets/images/swap_icon_white.png'
        : 'assets/images/swap_icon.png';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.title(' Amount (required)'),
        const Gap(4),
        const EnterAmount2(),
        // if (amount > 0) const BBText.title('    Approx fees: $finalFee sats'),
        const Gap(24),
        const BBText.title(' Add a Label'),
        const Gap(4),
        BBTextInput.big(
          uiKey: UIKeys.receiveDescriptionField,
          value: description,
          hint: 'Enter Label',
          onChanged: (txt) {
            context.read<ReceiveCubit>().descriptionChanged(txt);
          },
        ),
        const Gap(48),
        Center(
          child: BBButton.big(
            // leftIcon: FontAwesomeIcons.receipt,
            leftImage: swapIcon,
            buttonKey: UIKeys.receiveSavePaymentButton,
            loading: sending,
            disabled: sending,
            label: 'Create Swap',
            loadingText: 'Creating Swap',
            onPressed: () async {
              final amt = context.read<CurrencyCubit>().state.amount;
              final receiveWallet = context.read<ReceiveCubit>().state.wallet!;
              final label = context.read<ReceiveCubit>().state.description;

              final matchingWalletForRefund = context
                  .read<HomeBloc>()
                  .state
                  .walletsFromNetwork(receiveWallet.network)
                  // .map((bloc) => bloc.state.wallet)
                  .where(
                    (wallet) =>
                        wallet.baseWalletType != receiveWallet.baseWalletType,
                  )
                  .first;
              final refundAddress =
                  matchingWalletForRefund.lastGeneratedAddress;

              context.read<CreateSwapCubit>().createOnChainSwapForReceive(
                    toWallet: receiveWallet,
                    amount: amt,
                    refundAddress: refundAddress?.address ?? '',
                    direction: receiveWallet.isLiquid()
                        ? ChainSwapDirection.btcToLbtc
                        : ChainSwapDirection.lbtcToBtc,
                    label: label,
                  );
            },
          ),
        ),
        if (err.isNotEmpty) ...[
          const Gap(8),
          BBText.error(err),
        ],
        const Gap(40),
      ],
    );
  }
}

class CreateLightningInvoice extends StatelessWidget {
  const CreateLightningInvoice({super.key});

  @override
  Widget build(BuildContext context) {
    final description = context.select((ReceiveCubit _) => _.state.description);
    final err =
        context.select((CreateSwapCubit _) => _.state.errCreatingSwapInv);
    final creatingInv =
        context.select((CreateSwapCubit _) => _.state.generatingSwapInv);
    context.select((CreateSwapCubit x) => x.state.allFees);
    final amount = context.select((CurrencyCubit x) => x.state.amount);

    final isLiquid = context.select(
      (ReceiveCubit x) => x.state.wallet?.isLiquid(),
    );

    int finalFee = 0;

    final reverseFees =
        context.select((CreateSwapCubit x) => x.state.reverseFees);

    if (reverseFees != null) {
      if (isLiquid == true) {
        finalFee = (((reverseFees.lbtcFees.percentage) * amount / 100) +
                (reverseFees.lbtcFees.minerFees.claim.toInt()) +
                (reverseFees.lbtcFees.minerFees.lockup.toInt()))
            .toInt();
      } else {
        finalFee = (((reverseFees.btcFees.percentage) * amount / 100) +
                (reverseFees.btcFees.minerFees.claim.toInt()) +
                (reverseFees.btcFees.minerFees.lockup.toInt()))
            .toInt();
      }
    }
    /*
    if (allFees != null) {
      if (isLiquid == true) {
        finalFee = (((allFees.lbtcReverse.boltzFeesRate) * amount / 100) +
                (allFees.lbtcReverse.claimFeesEstimate) +
                (allFees.lbtcReverse.lockupFees))
            .toInt();
      } else {
        finalFee = (((allFees.btcReverse.boltzFeesRate) * amount / 100) +
                (allFees.btcReverse.claimFeesEstimate) +
                (allFees.btcReverse.lockupFees))
            .toInt();
      }
    }
    */

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.title(' Amount (required)'),
        const Gap(4),
        const EnterAmount2(),
        if (amount > 0) BBText.title('    Approx fees: $finalFee sats'),
        const Gap(24),
        const BBText.title(' Add a Label'),
        const Gap(4),
        BBTextInput.big(
          uiKey: UIKeys.receiveDescriptionField,
          value: description,
          hint: 'Enter Label',
          onChanged: (txt) {
            context.read<ReceiveCubit>().descriptionChanged(txt);
          },
        ),
        const Gap(48),
        Center(
          child: BBButton.big(
            leftSvgAsset: 'assets/request-payment.svg',
            buttonKey: UIKeys.receiveSavePaymentButton,
            loading: creatingInv,
            disabled: creatingInv,
            label: 'Create Invoice',
            loadingText: 'Creating Invoice',
            onPressed: () async {
              final amt = context.read<CurrencyCubit>().state.amount;
              final wallet = context.read<ReceiveCubit>().state.wallet!;
              final walletIsLiquid = wallet.isLiquid();
              final label = context.read<ReceiveCubit>().state.description;
              final isTestnet =
                  context.read<NetworkBloc>().state.networkData.testnet;
              final networkUrl = !walletIsLiquid
                  ? context.read<NetworkRepository>().getNetworkUrl
                  : context.read<NetworkRepository>().getLiquidNetworkUrl;

              context.read<CreateSwapCubit>().createRevSwapForReceive(
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

class BitcoinReceiveForm extends StatelessWidget {
  const BitcoinReceiveForm({super.key});

  @override
  Widget build(BuildContext context) {
    final description = context.select((ReceiveCubit _) => _.state.description);
    // final amount = context.select((CurrencyCubit x) => x.state.amount);

    // final isLiquid = context.select(
    //   (ReceiveCubit x) => x.state.walletBloc?.state.wallet?.isLiquid(),
    // );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.title('Request amount (optional)'),
        const Gap(4),
        const EnterAmount2(),
        const Gap(12),
        const BBText.title('Add a Label'),
        const Gap(4),
        BBTextInput.big(
          uiKey: UIKeys.receiveDescriptionField,
          value: description,
          hint: 'Enter Label',
          onChanged: (txt) {
            context.read<ReceiveCubit>().descriptionChanged(txt);
          },
        ),
        const Gap(12),
      ],
    );
  }
}

class SwapFeesDetails extends StatelessWidget {
  const SwapFeesDetails({super.key});

  @override
  Widget build(BuildContext context) {
    final swapTx = context.select((CreateSwapCubit _) => _.state.swapTx);
    if (swapTx == null) return const SizedBox.shrink();

    final isLn = context.select((ReceiveCubit x) => x.state.isLn());
    final isChainSwap =
        context.select((ReceiveCubit x) => x.state.isChainSwap());
    if (isLn == false && isChainSwap == false) return const SizedBox.shrink();

    final totalFees = swapTx.totalFees() ?? 0;

    final isLiquid = swapTx.isLiquid();
    final unitNetwork =
        isLiquid ? 'Liquid Network Bitcoin (L-BTC)' : 'On-chain Bitcoin (BTC)';

    String fromNetwork = '';
    String toNetwork = '';
    if (isChainSwap) {
      final fromBtc = swapTx.chainSwapDetails?.direction ==
          boltz.ChainSwapDirection.btcToLbtc;
      fromNetwork = fromBtc
          ? 'Bitcoin network payments'
          : 'Liquid network bitcoin (L-BTC)';
      toNetwork = fromBtc
          ? 'Liquid network bitcoin (L-BTC)'
          : 'Bitcoin network payments';
    }

    final fees = context.select(
      (CurrencyCubit x) =>
          x.state.getAmountInUnits(totalFees, removeText: true),
    );
    final units = context.select(
      (CurrencyCubit cubit) => cubit.state.getUnitString(),
    );

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: context.font.bodyMedium?.fontSize,
          color: context.colour.tertiary,
        ),
        children: <TextSpan>[
          TextSpan(
            text: isChainSwap
                ? '$fromNetwork are converted to $toNetwork. A swap fee of '
                : 'Lightning Network payments are converted instantly to $unitNetwork. A swap fee of ',
          ),
          TextSpan(
            text: '$fees $units',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const TextSpan(
            text: ' will be deducted',
          ),
        ],
      ),
    );
  }
}

class ReceiveQR extends StatelessWidget {
  const ReceiveQR({super.key});

  @override
  Widget build(BuildContext context) {
    final swapTx = context.select((CreateSwapCubit x) => x.state.swapTx);
    final amount =
        context.select((CurrencyCubit x) => x.state.amount / 100000000.0);
    final isTestnet =
        context.select((NetworkBloc x) => x.state.networkData.testnet);
    final isLiquid = context.select(
      (ReceiveCubit x) => x.state.wallet?.isLiquid() ?? false,
    );
    final bip21Address = context.select(
      (ReceiveCubit x) => x.state.getAddressWithAmountAndLabel(
        amount,
        isLiquid,
        swapTx: swapTx,
        isTestnet: isTestnet,
      ),
    );

    return ReceiveQRDisplay(address: bip21Address);
  }
}

class ReceiveQRDisplay extends StatelessWidget {
  const ReceiveQRDisplay({super.key, required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () async {
          if (locator.isRegistered<Clippboard>()) {
            await locator<Clippboard>().copy(address);
          }
        },
        child: Column(
          children: [
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
  const ReceiveAddress({super.key, required this.addressQr, this.swapTx});

  final String addressQr;
  final SwapTx? swapTx;

  @override
  Widget build(BuildContext context) {
    return ReceiveDisplayAddress(addressQr: addressQr);
  }
}

class RequestedAmount extends StatelessWidget {
  const RequestedAmount({super.key});

  @override
  Widget build(BuildContext context) {
    final payNetwork =
        context.select((ReceiveCubit x) => x.state.paymentNetwork);
    final swapTx = context.select((CreateSwapCubit x) => x.state.swapTx);
    final amount = context.select((CurrencyCubit x) => x.state.amount);
    final requestedAmount = payNetwork == PaymentNetwork.lightning
        ? (swapTx?.outAmount ?? 0)
        : amount;
    final requestedAmountStr = context.select(
      (CurrencyCubit x) =>
          x.state.getAmountInUnits(requestedAmount, removeText: true),
    );
    final units = context.select(
      (CurrencyCubit cubit) => cubit.state.getUnitString(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BBText.body(
          'Requested amount',
        ),
        BBText.bodyBold('$requestedAmountStr $units'),
      ],
    );
  }
}

class PaymentDescription extends StatelessWidget {
  const PaymentDescription({super.key});

  @override
  Widget build(BuildContext context) {
    final description = context.select((ReceiveCubit _) => _.state.description);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BBText.body('Payment description'),
        BBText.bodyBold(description),
      ],
    );
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
    // final address = widget.minify
    //     ? widget.addressQr.length < 14
    //         ? widget.addressQr
    //         : widget.addressQr.substring(0, 10) + ' ... ' + widget.addressQr.substring(widget.addressQr.length - 5)
    //     : widget.addressQr;
    final paymentNetwork =
        context.select((ReceiveCubit x) => x.state.paymentNetwork);
    String receiveAddressLabel = 'Payment invoice';

    final isPayjoin = context.select((ReceiveCubit _) => _.state.isPayjoin);

    if (paymentNetwork == PaymentNetwork.bitcoin) {
      receiveAddressLabel = isPayjoin ? 'Payjoin address' : 'Bitcoin address';
    } else if (paymentNetwork == PaymentNetwork.liquid) {
      receiveAddressLabel = 'Liquid address';
    }

    final swapTx = context.select((CreateSwapCubit x) => x.state.swapTx);
    final amount =
        context.select((CurrencyCubit x) => x.state.amount / 100000000.0);
    final isTestnet =
        context.select((NetworkBloc x) => x.state.networkData.testnet);
    final isLiquid = context.select(
      (ReceiveCubit x) => x.state.wallet?.isLiquid() ?? false,
    );
    final bip21Address = context.select(
      (ReceiveCubit x) => x.state.getAddressWithAmountAndLabel(
        swapTx?.isChainSwap() == true
            ? (swapTx!.outAmount.toDouble() / 100000000.0)
            : amount,
        swapTx?.isChainSwap() == true ? swapTx!.isLiquid() : isLiquid,
        swapTx: swapTx,
        isTestnet: isTestnet,
      ),
    );

    final addr = bip21Address.isNotEmpty ? bip21Address : widget.addressQr;
    final addrOnly = widget.addressQr;
    final isPjReceiver =
        context.select((ReceiveCubit x) => x.state.payjoinReceiver);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BBText.body(receiveAddressLabel),
          if (isPayjoin == false && paymentNetwork == PaymentNetwork.bitcoin)
            Card(
              color: Colors.yellow[100],
              margin: const EdgeInsets.all(10),
              child: const ListTile(
                leading: Icon(Icons.warning, color: Colors.orange),
                title: Text(
                  'Payjoin',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                subtitle: Text(
                  'To receive with Payjoin, your wallet must already hold Bitcoin',
                  style: TextStyle(color: Colors.black87),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    if (locator.isRegistered<Clippboard>()) {
                      await locator<Clippboard>().copy(addr);
                    }
                  },
                  child: BBText.bodySmall(
                    addr,
                    isBlue: true,
                  ),
                ),
              ),
              IconButton(
                onPressed: () async {
                  if (locator.isRegistered<Clippboard>()) {
                    await locator<Clippboard>().copy(addr);
                  }
                },
                iconSize: 24,
                color: Colors.blue,
                icon: const Icon(Icons.copy),
              ),
            ],
          ),
          if (isPjReceiver != null)
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      if (locator.isRegistered<Clippboard>()) {
                        await locator<Clippboard>().copy(addrOnly);
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const BBText.bodySmall('Address only:'),
                        BBText.bodySmall(
                          addrOnly,
                          isBlue: true,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    if (locator.isRegistered<Clippboard>()) {
                      await locator<Clippboard>().copy(addrOnly);
                    }
                  },
                  iconSize: 24,
                  color: Colors.blue,
                  icon: const Icon(Icons.copy),
                ),
              ],
            ),
        ],
      ),
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
