import 'package:bb_mobile/_model/swap.dart';
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
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/controls.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/_ui/molecules/wallet/wallet_dropdown.dart';
import 'package:bb_mobile/_ui/warning.dart';
import 'package:bb_mobile/currency/amount_input.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/receive/bloc/receive_cubit.dart';
import 'package:bb_mobile/receive/listeners.dart';
import 'package:bb_mobile/settings/bloc/lighting_cubit.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/swap/create_swap_bloc/swap_cubit.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:boltz_dart/boltz_dart.dart' as boltz;
import 'package:boltz_dart/boltz_dart.dart';
import 'package:flutter/material.dart';
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
  const ReceivePage({super.key, this.walletBloc});

  final WalletBloc? walletBloc;

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage> {
  late ReceiveCubit _receiveCubit;
  late CurrencyCubit _currencyCubit;
  late CreateSwapCubit _swapCubit;

  @override
  void initState() {
    _swapCubit = CreateSwapCubit(
      walletSensitiveRepository: locator<WalletSensitiveStorageRepository>(),
      swapBoltz: locator<SwapBoltz>(),
      walletTx: locator<WalletTx>(),
      homeCubit: context.read<HomeCubit>(),
      watchTxsBloc: context.read<WatchTxsBloc>(),
      networkCubit: context.read<NetworkCubit>(),
    )..fetchFees(context.read<NetworkCubit>().state.testnet);

    _currencyCubit = CurrencyCubit(
      hiveStorage: locator<HiveStorage>(),
      bbAPI: locator<BullBitcoinAPI>(),
      defaultCurrencyCubit: context.read<CurrencyCubit>(),
    );

    _receiveCubit = ReceiveCubit(
      walletAddress: locator<WalletAddress>(),
      walletsStorageRepository: locator<WalletsStorageRepository>(),
      walletBloc: widget.walletBloc,
      defaultPayjoin: locator<SettingsCubit>().state.defaultPayjoin,
    );

    final network = context.read<NetworkCubit>().state.getBBNetwork();
    final walletBloc = widget.walletBloc ??
        context.read<HomeCubit>().state.getMainInstantWallet(network);

    if (walletBloc!.state.wallet!.isLiquid()) {
      _receiveCubit.updateWalletType(
        PaymentNetwork.lightning,
        context.read<NetworkCubit>().state.testnet,
        onStart: true,
      );
    } else {
      _receiveCubit.updateWalletType(
        PaymentNetwork.bitcoin,
        context.read<NetworkCubit>().state.testnet,
        onStart: true,
      );
    }

    _receiveCubit.updateWalletBloc(walletBloc);

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
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
          body: const _WalletProvider(
            child: _Screen(),
          ),
        ),
      ),
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

    final watchOnly =
        context.select((WalletBloc x) => x.state.wallet!.watchOnly());
    final mainWallet =
        context.select((ReceiveCubit x) => x.state.checkIfMainWalletSelected());
    final receiveWallet = context.select((WalletBloc x) => x.state.wallet);

    final walletIsLiquid = context.select(
      (WalletBloc x) => x.state.wallet!.isLiquid(),
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

    if (showWarning && !removeWarning && !walletIsLiquid)
      return const _Warnings();

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
              const ReceiveQR(),
              const Gap(8),
              ReceiveAddress(
                swapTx: swapTx,
                addressQr: addressQr,
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

class ReceiveWalletsDropDown extends StatelessWidget {
  const ReceiveWalletsDropDown({super.key});

  @override
  Widget build(BuildContext context) {
    final oneWallet = context.select((ReceiveCubit _) => _.state.oneWallet);
    final network = context.select((NetworkCubit _) => _.state.getBBNetwork());
    final walletBlocs = context
        .select((HomeCubit _) => _.state.walletBlocsFromNetwork(network));
    final selectedWalletBloc =
        context.select((ReceiveCubit _) => _.state.walletBloc);

    // final walletBloc = selectedWalletBloc ?? walletBlocs.first;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: oneWallet ? 0.5 : 1,
      child: IgnorePointer(
        ignoring: oneWallet,
        child: WalletDropDown(
          items: walletBlocs.map((wb) => wb.state.wallet!).toList(),
          onChanged: (wallet) {
            final blocs =
                walletBlocs.where((wb) => wb.state.wallet == wallet).toList();
            if (blocs.isNotEmpty) {
              context.read<CreateSwapCubit>().removeWarnings();
              context.read<ReceiveCubit>().updateWalletBloc(blocs[0]);
            }
          },
          value:
              selectedWalletBloc?.state.wallet ?? walletBlocs[0].state.wallet!,
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
            if (paymentNetwork == PaymentNetwork.lightning)
              context.read<CreateSwapCubit>().clearSwapTx();

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
    final isTestnet = context.select((NetworkCubit x) => x.state.testnet);
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
    final allFees = context.select((CreateSwapCubit x) => x.state.allFees);
    final amount = context.select((CurrencyCubit x) => x.state.amount);

    final isLiquid = context.select(
      (ReceiveCubit x) => x.state.walletBloc?.state.wallet?.isLiquid(),
    );
    final err = context.select((CreateSwapCubit _) => _.state.err());

    final generatingInv = context
        .select((CreateSwapCubit cubit) => cubit.state.generatingSwapInv);
    final sending = generatingInv;

    const int finalFee = 0;

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
              final receiveWallet =
                  context.read<ReceiveCubit>().state.walletBloc!.state.wallet!;
              final label = context.read<ReceiveCubit>().state.description;

              final matchingWalletForRefund = context
                  .read<HomeCubit>()
                  .state
                  .walletBlocsFromNetwork(receiveWallet.network)
                  .map((bloc) => bloc.state.wallet)
                  .where(
                    (wallet) =>
                        wallet?.baseWalletType != receiveWallet.baseWalletType,
                  )
                  .first;
              final refundAddress =
                  matchingWalletForRefund?.lastGeneratedAddress;

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
    final allFees = context.select((CreateSwapCubit x) => x.state.allFees);
    final amount = context.select((CurrencyCubit x) => x.state.amount);

    final isLiquid = context.select(
      (ReceiveCubit x) => x.state.walletBloc?.state.wallet?.isLiquid(),
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
            // leftIcon: FontAwesomeIcons.receipt,
            leftSvgAsset: 'assets/request-payment.svg',
            buttonKey: UIKeys.receiveSavePaymentButton,
            loading: creatingInv,
            disabled: creatingInv,
            label: 'Create Invoice',
            loadingText: 'Creating Invoice',
            onPressed: () async {
              final amt = context.read<CurrencyCubit>().state.amount;
              final wallet =
                  context.read<ReceiveCubit>().state.walletBloc!.state.wallet!;
              final walletIsLiquid = wallet.isLiquid();
              final label = context.read<ReceiveCubit>().state.description;
              final isTestnet = context.read<NetworkCubit>().state.testnet;
              final networkUrl = !walletIsLiquid
                  ? context.read<NetworkCubit>().state.getNetworkUrl()
                  : context.read<NetworkCubit>().state.getLiquidNetworkUrl();

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

    // return BBText.bodySmall(
    //   'Lightning Network payments are converted instantly to Liquid Network Bitcoin (L-BTC). A swap fee of $fees $units will be deducted',
    // );

    /*
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.body('Total fees:'),
        BBText.bodyBold('$fees $units'),
        const Gap(16),
      ],
    );
    */
  }
}

class ReceiveQR extends StatelessWidget {
  const ReceiveQR({super.key});

  @override
  Widget build(BuildContext context) {
    final swapTx = context.select((CreateSwapCubit x) => x.state.swapTx);
    final amount =
        context.select((CurrencyCubit x) => x.state.amount / 100000000.0);
    final isTestnet = context.select((NetworkCubit x) => x.state.testnet);
    final isLiquid = context.select(
      (ReceiveCubit x) => x.state.walletBloc?.state.wallet?.isLiquid() ?? false,
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
          if (locator.isRegistered<Clippboard>())
            await locator<Clippboard>().copy(address);

          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(content: Text('Copied to clipboard')),
          // );
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

    if (paymentNetwork == PaymentNetwork.bitcoin) {
      receiveAddressLabel = 'Bitcoin address';
    } else if (paymentNetwork == PaymentNetwork.liquid) {
      receiveAddressLabel = 'Liquid address';
    }

    final swapTx = context.select((CreateSwapCubit x) => x.state.swapTx);
    final amount =
        context.select((CurrencyCubit x) => x.state.amount / 100000000.0);
    final isTestnet = context.select((NetworkCubit x) => x.state.testnet);
    final isLiquid = context.select(
      (ReceiveCubit x) => x.state.walletBloc?.state.wallet?.isLiquid() ?? false,
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

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: !showToast
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText.body(receiveAddressLabel),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          if (locator.isRegistered<Clippboard>())
                            await locator<Clippboard>().copy(addr);

                          // ScaffoldMessenger.of(context).showSnackBar(
                          //   const SnackBar(
                          //     content: Text('Copied to clipboard'),
                          //   ),
                          // );
                        },
                        child: BBText.bodySmall(
                          addr,
                          isBlue: true,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        if (locator.isRegistered<Clippboard>())
                          await locator<Clippboard>().copy(addr);

                        // ScaffoldMessenger.of(context).showSnackBar(
                        //   const SnackBar(content: Text('Copied to clipboard')),
                        // );
                      },
                      iconSize: 24,
                      color: Colors.blue,
                      icon: const Icon(Icons.copy),
                    ),
                  ],
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

// class CreateInvoice extends StatelessWidget {
//   const CreateInvoice({super.key});

//   static Future openPopUp(BuildContext context) async {
//     final receiveCubit = context.read<ReceiveCubit>();
//     final currencyCubit = context.read<CurrencyCubit>();

//     if (currencyCubit.state.amount > 0)
//       currencyCubit.convertAmtOnCurrencyChange();

//     return showBBBottomSheet(
//       context: context,
//       child: BlocProvider.value(
//         value: receiveCubit,
//         child: BlocProvider.value(
//           value: currencyCubit,
//           child: BlocListener<ReceiveCubit, ReceiveState>(
//             listenWhen: (previous, current) =>
//                 previous.savedInvoiceAmount != current.savedInvoiceAmount ||
//                 previous.savedDescription != current.savedDescription,
//             listener: (context, state) {
//               context.pop();
//             },
//             child: const Padding(
//               padding: EdgeInsets.all(30),
//               child: CreateInvoice(),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final description = context.select((ReceiveCubit _) => _.state.description);

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         BBHeader.popUpCenteredText(
//           text: 'Request a Payment',
//           onBack: () {
//             context.read<ReceiveCubit>().clearInvoiceFields();
//             context.read<CurrencyCubit>().reset();

//             context.pop();
//           },
//         ),
//         const Gap(40),
//         const Gap(4),
//         const EnterAmount(uiKey: UIKeys.receiveAmountField),
//         const Gap(24),
//         const BBText.title('   Public description'),
//         const Gap(4),
//         BBTextInput.big(
//           uiKey: UIKeys.receiveDescriptionField,
//           value: description,
//           hint: 'Enter description',
//           onChanged: (txt) {
//             context.read<ReceiveCubit>().descriptionChanged(txt);
//           },
//         ),
//         const Gap(40),
//         BBButton.big(
//           buttonKey: UIKeys.receiveSavePaymentButton,
//           label: 'Save',
//           onPressed: () {
//             final amt = context.read<CurrencyCubit>().state.amount;
//             context.read<ReceiveCubit>().saveFinalInvoiceClicked(amt);
//           },
//         ),
//         const Gap(40),
//       ],
//     );
//   }
// }

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

// class AddLabelButton extends StatelessWidget {
//   const AddLabelButton({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return BBButton.big(
//       label: 'Add address label',
//       // leftIcon: FontAwesomeIcons.penToSquare,
//       leftSvgAsset: 'assets/edit.svg',
//       onPressed: () {
//         AddLabelPopUp.openPopUp(context);
//       },
//     );
//   }
// }

// class AddLabelPopUp extends StatelessWidget {
//   const AddLabelPopUp({super.key});

//   static Future openPopUp(BuildContext context) async {
//     final receive = context.read<ReceiveCubit>();
//     return showBBBottomSheet(
//       context: context,
//       child: BlocProvider.value(
//         value: receive,
//         child: const Padding(
//           padding: EdgeInsets.all(30),
//           child: AddLabelPopUp(),
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final value = context.select((ReceiveCubit x) => x.state.description);
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         BBHeader.popUpCenteredText(
//           text: 'Add Label',
//           isLeft: true,
//           onBack: () {
//             context.pop();
//           },
//         ),
//         const Gap(24),
//         BBTextInput.big(
//           hint: 'Enter label',
//           value: value,
//           onChanged: (txt) {
//             context.read<ReceiveCubit>().descriptionChanged(txt);
//           },
//         ),
//         const Gap(40),
//         Center(
//           child: BBButton.big(
//             label: 'Save',
//             onPressed: () {
//               context.read<ReceiveCubit>().saveAddrressLabel();
//             },
//           ),
//         ),
//         const Gap(40),
//       ],
//     );
//   }
// }
