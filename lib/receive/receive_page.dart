import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_pkg/bull_bitcoin_api.dart';
import 'package:bb_mobile/_pkg/clipboard.dart';
import 'package:bb_mobile/_pkg/consts/keys.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
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
import 'package:bb_mobile/_ui/organisms/swap_widget2.dart';
import 'package:bb_mobile/_ui/warning.dart';
import 'package:bb_mobile/currency/amount_input.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/receive/bloc/receive_cubit.dart';
import 'package:bb_mobile/receive/listeners.dart';
import 'package:bb_mobile/send/bloc/send_cubit.dart';
import 'package:bb_mobile/send/send_page.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/swap/create_swap_bloc/swap_cubit.dart';
import 'package:bb_mobile/swap/swap_page_progress.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_bloc.dart';
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
  late CreateSwapCubit _swapCubit;
  late SendCubit _sendCubit;

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

    _sendCubit = SendCubit(
      walletTx: locator<WalletTx>(),
      barcode: locator<Barcode>(),
      defaultRBF: locator<SettingsCubit>().state.defaultRBF,
      fileStorage: locator<FileStorage>(),
      networkCubit: locator<NetworkCubit>(),
      homeCubit: locator<HomeCubit>(),
      swapBoltz: locator<SwapBoltz>(),
      currencyCubit: _currencyCubit,
      openScanner: false,
      walletBloc: walletBloc,
      swapCubit: _swapCubit,
    );

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _receiveCubit),
        BlocProvider.value(value: _currencyCubit),
        BlocProvider.value(value: _swapCubit),
        BlocProvider.value(value: _sendCubit),
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
    final showQR = context.select((ReceiveCubit x) => x.state.showQR(swapTx));

    final watchOnly =
        context.select((WalletBloc x) => x.state.wallet!.watchOnly());
    final mainWallet =
        context.select((ReceiveCubit x) => x.state.checkIfMainWalletSelected());
    final receiveWallet = context.select((WalletBloc x) => x.state.wallet);

    final walletIsLiquid = context.select(
      (WalletBloc x) => x.state.wallet!.baseWalletType == BaseWalletType.Liquid,
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

    // ****************
    // BEGIN: ON CHAIN
    // ****************

    final chainNetwork = context.read<NetworkCubit>().state.getBBNetwork();
    final chainWalletBlocs =
        context.read<HomeCubit>().state.walletBlocsFromNetwork(chainNetwork);
    // final chainWallets = chainWalletBlocs
    //     .map((bloc) => bloc.state.wallet!)
    //     .where((w) => w.baseWalletType != receiveWallet?.baseWalletType)
    //     .toList();
    final chainWallets =
        chainWalletBlocs.map((bloc) => bloc.state.wallet!).toList();

    final chainSent = context.select((SendCubit cubit) => cubit.state.sent);
    if (chainSent) return const SendingOnChainTx();

    final generatingInv = context
        .select((CreateSwapCubit cubit) => cubit.state.generatingSwapInv);
    final sendingg = context.select((SendCubit cubit) => cubit.state.sending);
    final buildingOnChain =
        context.select((SendCubit cubit) => cubit.state.buildingOnChain);
    final chainSending = generatingInv || sendingg || buildingOnChain;

    final chainSigned = context.select((SendCubit cubit) => cubit.state.signed);

    final unitInSats = context.select(
      (CurrencyCubit cubit) => cubit.state.unitsInSats,
    );

    final swapFees = swapTx?.totalFees() ?? 0;
    final senderFee =
        context.select((SendCubit send) => send.state.psbtSignedFeeAmount ?? 0);
    final fee = swapFees + senderFee;
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

    // **************
    // END: ON CHAIN
    // **************

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
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
                const Gap(16),
              ],
              if (isChainSwap)
                Column(
                  children: [
                    SwapWidget2(
                      loading: chainSending,
                      wallets: chainWallets,
                      hideToWallet: true,
                      toWalletId: receiveWallet?.id,
                      swapButtonLabel:
                          chainSigned == true ? 'Broadcast' : 'Swap',
                      swapButtonLoadingLabel: chainSigned == true
                          ? 'Broadcasting'
                          : 'Creating swap',
                      unitInSats: unitInSats,
                      fee: swapTx != null ? feeStr : null,
                      feeFiat:
                          swapTx != null ? '~ $feeFiat $fiatCurrency' : null,
                      onChange: (
                        Wallet fromWallet,
                        Wallet toWallet,
                        int amount,
                        bool sweep,
                      ) {
                        if (swapTx != null) {
                          context.read<CreateSwapCubit>().clearSwapTx();
                          context.read<SendCubit>().reset();
                        }
                      },
                      onSwapPressed: (
                        Wallet fromWallet,
                        Wallet toWallet,
                        int amount,
                        bool sweep,
                      ) {},
                    ),
                    const SendErrDisplay(),
                  ],
                ),
              if (!isChainSwap && showQR) ...[
                const ReceiveQR(),
                const Gap(8),
                const ReceiveAddress(),
                const Gap(8),
                if (shouldShowForm) const BitcoinReceiveForm(),
                if (paymentNetwork == PaymentNetwork.lightning || formSubmitted)
                  const RequestedAmount(),
                if (shouldShownDescription) const Gap(8),
                if (shouldShownDescription) const PaymentDescription(),
                const Gap(16),
                const SwapFeesDetails(),
              ] else if (!isChainSwap) ...[
                // const Gap(24),
                const CreateLightningInvoice(),
                // const Gap(24),
                // const SwapHistoryButton(),
              ],
              const Gap(2),
              if (!isChainSwap) const WalletActions(),
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
    final oneWallet = context.select((ReceiveCubit _) => _.state.oneWallet);
    final network = context.select((NetworkCubit _) => _.state.getBBNetwork());
    final walletBlocs = context
        .select((HomeCubit _) => _.state.walletBlocsFromNetwork(network));
    final selectedWalletBloc =
        context.select((ReceiveCubit _) => _.state.walletBloc);

    final walletBloc = selectedWalletBloc ?? walletBlocs.first;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: oneWallet ? 0.3 : 1,
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
        if (paymentNetwork == PaymentNetwork.lightning)
          context.read<CreateSwapCubit>().clearSwapTx();

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
  const _SaveLabelButton({
    super.key,
  });

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
                (reverseFees.lbtcFees.minerFees.claim) +
                (reverseFees.lbtcFees.minerFees.lockup))
            .toInt();
      } else {
        finalFee = (((reverseFees.btcFees.percentage) * amount / 100) +
                (reverseFees.btcFees.minerFees.claim) +
                (reverseFees.btcFees.minerFees.lockup))
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
              final walletIsLiquid =
                  wallet.baseWalletType == BaseWalletType.Liquid;
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
        // Center(
        //   child: BBButton.big(
        //     label: 'Submit',
        //     onPressed: () async {
        //       context.read<ReceiveCubit>().setReceiveFormSubmitted(true);
        //       final amt = context.read<CurrencyCubit>().state.amount;
        //       print(amt);
        //     },
        //   ),
        // ),
        const Gap(16),
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
    if (!isLn) return const SizedBox.shrink();

    final totalFees = swapTx.totalFees() ?? 0;

    final isLiquid = swapTx.isLiquid();
    final unitNetwork =
        isLiquid ? 'Liquid Network Bitcoin (L-BTC)' : 'On-chain Bitcoin (BTC)';

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
            text:
                'Lightning Network payments are converted instantly to $unitNetwork. A swap fee of ',
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
  const ReceiveAddress({super.key});

  @override
  Widget build(BuildContext context) {
    final swapTx = context.select((CreateSwapCubit x) => x.state.swapTx);
    final addressQr =
        context.select((ReceiveCubit x) => x.state.getQRStr(swapTx: swapTx));

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
        amount,
        isLiquid,
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
