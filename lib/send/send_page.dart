import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_pkg/bull_bitcoin_api.dart';
import 'package:bb_mobile/_pkg/clipboard.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/launcher.dart';
import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/wallet/repository/sensitive_storage.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/controls.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/currency/amount_input.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/network_fees/bloc/networkfees_cubit.dart';
import 'package:bb_mobile/network_fees/popup.dart';
import 'package:bb_mobile/send/advanced.dart';
import 'package:bb_mobile/send/bloc/send_cubit.dart';
import 'package:bb_mobile/send/bloc/send_state.dart';
import 'package:bb_mobile/send/listeners.dart';
import 'package:bb_mobile/send/psbt.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/swap/bloc/swap_cubit.dart';
import 'package:bb_mobile/swap/send.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SendPage extends StatefulWidget {
  const SendPage({super.key, this.openScanner = false, this.walletId});

  final bool openScanner;
  final String? walletId;
  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> {
  late SendCubit send;
  late NetworkFeesCubit networkFees;

  late SwapCubit swap;
  late CurrencyCubit currency;

  @override
  void initState() {
    swap = SwapCubit(
      walletSensitiveRepository: locator<WalletSensitiveStorageRepository>(),
      swapBoltz: locator<SwapBoltz>(),
      walletTx: locator<WalletTx>(),
    )..fetchFees(context.read<NetworkCubit>().state.testnet);

    networkFees = NetworkFeesCubit(
      networkCubit: locator<NetworkCubit>(),
      hiveStorage: locator<HiveStorage>(),
      mempoolAPI: locator<MempoolAPI>(),
      defaultNetworkFeesCubit: context.read<NetworkFeesCubit>(),
    );

    currency = CurrencyCubit(
      hiveStorage: locator<HiveStorage>(),
      bbAPI: locator<BullBitcoinAPI>(),
      defaultCurrencyCubit: context.read<CurrencyCubit>(),
    );

    WalletBloc? walletBloc;

    if (widget.walletId != null)
      walletBloc =
          context.read<HomeCubit>().state.getWalletBlocById(widget.walletId!);

    send = SendCubit(
      walletTx: locator<WalletTx>(),
      barcode: locator<Barcode>(),
      defaultRBF: locator<SettingsCubit>().state.defaultRBF,
      fileStorage: locator<FileStorage>(),
      networkCubit: locator<NetworkCubit>(),
      homeCubit: locator<HomeCubit>(),
      swapBoltz: locator<SwapBoltz>(),
      currencyCubit: currency,
      openScanner: widget.openScanner,
      walletBloc: walletBloc,
    );

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: send),
        BlocProvider.value(value: currency),
        BlocProvider.value(value: swap),
        BlocProvider.value(value: networkFees),
      ],
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: const _SendAppBar(),
          automaticallyImplyLeading: false,
        ),
        body: const SendListeners(
          child: _WalletProvider(
            child: _Screen(),
          ),
        ),
      ),
    );
  }
}

class _WalletProvider extends StatelessWidget {
  const _WalletProvider({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final send = context.select((SendCubit _) => _.state.selectedWalletBloc);

    if (send == null) return child;
    return BlocProvider.value(value: send, child: child);
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    final signed = context.select((SendCubit cubit) => cubit.state.signed);
    final sent = context.select((SendCubit cubit) => cubit.state.sent);
    final isLn = context.select((SendCubit cubit) => cubit.state.isLnInvoice());
    // final showSend =
    //     context.select((SendCubit cubit) => cubit.state.showSendButton);

    if (sent && isLn) return const SendingLnTx();

    return ColoredBox(
      color: sent ? Colors.green : context.colour.background,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (signed && !isLn) ...[
                if (!sent) const TxDetailsScreen() else const TxSuccess(),
              ] else ...[
                const Gap(32),
                const WalletSelectionDropDown(),
                const Gap(8),
                const _Balance(),
                const Gap(48),
                const AddressField(),
                const Gap(24),
                const AmountField(),
                if (!isLn) ...[
                  const Gap(24),
                  const NetworkFees(),
                ],
                const Gap(8),
                const AdvancedOptions(),
              ],
              const _SendButton(),
              const SendErrDisplay(),
              const Gap(80),
            ],
          ),
        ),
      ),
    );
  }
}

class WalletSelectionDropDown extends StatelessWidget {
  const WalletSelectionDropDown();

  @override
  Widget build(BuildContext context) {
    final enableDropdown = context
        .select((SendCubit cubit) => cubit.state.enabledWallets.isNotEmpty);

    final network = context.select((NetworkCubit _) => _.state.getBBNetwork());
    final walletBlocs = context
        .select((HomeCubit _) => _.state.walletBlocsFromNetwork(network));
    final selectedWalletBloc =
        context.select((SendCubit _) => _.state.selectedWalletBloc);

    final walletBloc = selectedWalletBloc ?? walletBlocs.first;

    return GestureDetector(
      onTap: () {
        if (!enableDropdown)
          context.read<SendCubit>().disabledDropdownClicked();
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: enableDropdown ? 1 : 0.3,
        child: AbsorbPointer(
          absorbing: !enableDropdown,
          child: BBDropDown<WalletBloc>(
            items: {
              for (final wallet in walletBlocs)
                wallet: (
                  label: wallet.state.wallet!.name ??
                      wallet.state.wallet!.sourceFingerprint,
                  enabled: context
                      .read<SendCubit>()
                      .state
                      .walletEnabled(wallet.state.wallet!.id),
                ),
            },
            value: walletBloc,
            onChanged: (bloc) {
              context.read<SendCubit>().updateWalletBloc(bloc);
            },
          ).animate().fadeIn(),
        ),
      ),
    );
  }
}

class _Balance extends StatelessWidget {
  const _Balance();

  @override
  Widget build(BuildContext context) {
    final showSend =
        context.select((SendCubit cubit) => cubit.state.showSendButton);
    if (!showSend) return const SizedBox(height: 24);

    return const Center(child: SendWalletBalance()).animate().fadeIn();
  }
}

class AddressField extends StatefulWidget {
  const AddressField({super.key});

  @override
  State<AddressField> createState() => _AddressFieldState();
}

class _AddressFieldState extends State<AddressField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    final address = context.select((SendCubit cubit) => cubit.state.address);
    if (_controller.text != address) {
      _controller.text = address;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.title('Bitcoin payment address or invoice'),
        const Gap(4),
        BBTextInput.bigWithIcon2(
          focusNode: _focusNode,
          hint: 'Enter address',
          value: address,
          rightIcon: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () async {
                  if (!locator.isRegistered<Clippboard>()) return;
                  final data = await locator<Clippboard>().paste();
                  if (data == null) return;
                  context.read<SwapCubit>().clearErrors();
                  context.read<SendCubit>().updateAddress(data);
                },
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                color: context.colour.onBackground,
                icon: const FaIcon(FontAwesomeIcons.paste),
              ),
              IconButton(
                onPressed: context.read<SendCubit>().scanAddress,
                icon: FaIcon(
                  FontAwesomeIcons.barcode,
                  color: context.colour.onBackground,
                ),
              ),
            ],
          ),
          onChanged: (value) {
            context.read<SwapCubit>().clearErrors();
            context.read<SendCubit>().updateAddress(value);
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }
}

class AmountField extends StatelessWidget {
  const AmountField({super.key});

  @override
  Widget build(BuildContext context) {
    final sendAll =
        context.select((SendCubit cubit) => cubit.state.sendAllCoin);
    final isLnInvoice =
        context.select((SendCubit cubit) => cubit.state.isLnInvoice());

    if (isLnInvoice) return const SendInvAmtDisplay();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.title('Amount to send'),
        const Gap(4),
        EnterAmount2(sendAll: sendAll),
      ],
    );
  }
}

class NetworkFees extends StatelessWidget {
  const NetworkFees({super.key});

  @override
  Widget build(BuildContext context) {
    final showSend =
        context.select((SendCubit cubit) => cubit.state.showSendButton);

    final isLiquid =
        context.select((SendCubit cubit) => cubit.state.isLiquidPayment());

    if (!showSend || isLiquid) return const SizedBox.shrink();

    return const SelectFeesButton().animate().fadeIn();
  }
}

class AdvancedOptions extends StatelessWidget {
  const AdvancedOptions({super.key});

  @override
  Widget build(BuildContext context) {
    final showSend = context.select((SendCubit _) => _.state.showSendButton);
    final isLn = context.select((SendCubit _) => _.state.isLnInvoice());
    final isLiquid = context.select((SendCubit _) => _.state.isLiquidPayment());

    if (!showSend || isLn || isLiquid) return const SizedBox.shrink();

    final text =
        context.select((SendCubit _) => _.state.advancedOptionsButtonText());
    return Column(
      children: [
        BBButton.text(
          onPressed: () {
            AdvancedOptionsPopUp.openPopup(context);
          },
          label: text,
        ).animate().fadeIn(),
        const Gap(48),
      ],
    );
  }
}

class SendErrDisplay extends StatelessWidget {
  const SendErrDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final errSend = context.select((SendCubit cubit) => cubit.state.errors());
    final errSwap = context.select((SwapCubit cubit) => cubit.state.err());

    final err = errSwap.isNotEmpty ? errSwap : errSend;

    if (err.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Center(child: BBText.error(err)),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton();

  @override
  Widget build(BuildContext context) {
    final showSend =
        context.select((SendCubit cubit) => cubit.state.showSendButton);
    final sent = context.select((SendCubit cubit) => cubit.state.sent);
    if (!showSend || sent) return const SizedBox.shrink();

    final watchOnly =
        context.select((WalletBloc cubit) => cubit.state.wallet!.watchOnly());

    final generatingInv =
        context.select((SwapCubit cubit) => cubit.state.generatingSwapInv);
    final sendingg = context.select((SendCubit cubit) => cubit.state.sending);
    final sending = generatingInv || sendingg;

    final signed = context.select((SendCubit cubit) => cubit.state.signed);

    final label = watchOnly
        ? 'Generate PSBT'
        : signed
            ? sending
                ? 'Broadcasting'
                : 'Confirm'
            : sending
                ? 'Building Tx'
                : 'Send';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Gap(24),
        Center(
          child: BlocListener<SendCubit, SendState>(
            listenWhen: (previous, current) =>
                previous.tx != current.tx &&
                current.psbt.isNotEmpty &&
                current.errSending.isEmpty,
            listener: (context, state) {
              PSBTPopUp.openPopUp(context);
            },
            child: BBButton.big(
              loading: sending,
              disabled: sending,
              leftIcon: Icons.send,
              onPressed: () async {
                if (sending) return;
                final isLn = context.read<SendCubit>().state.isLnInvoice();

                if (!signed) {
                  if (!isLn) {
                    final fees = context
                        .read<NetworkFeesCubit>()
                        .state
                        .selectedOrFirst(false);
                    context
                        .read<SendCubit>()
                        .confirmClickedd(networkFees: fees);
                    return;
                  }
                  context.read<SendCubit>().sendSwapClicked();
                  // final wallet = context.read<WalletBloc>().state.wallet!;
                  // final isLiq = wallet.isLiquid();
                  // final networkurl = !isLiq
                  //     ? context.read<NetworkCubit>().state.getNetworkUrl()
                  //     : context
                  //         .read<NetworkCubit>()
                  //         .state
                  //         .getLiquidNetworkUrl();

                  // context.read<SwapCubit>().createSubSwapForSend(
                  //       wallet: wallet,
                  //       invoice: context.read<SendCubit>().state.address,
                  //       amount: context.read<CurrencyCubit>().state.amount,
                  //       isTestnet: context.read<NetworkCubit>().state.testnet,
                  //       networkUrl: networkurl,
                  //     );
                  return;
                }

                if (!isLn) {
                  context.read<SendCubit>().sendClicked();
                  return;
                }
                // final swaptx = context.read<SwapCubit>().state.swapTx!;
                // context.read<SendCubit>().sendClicked(swaptx: swaptx);
              },
              label: label,
            ),
          ),
        ),
      ],
    ).animate().fadeIn();
  }
}

class PaymentSent extends StatelessWidget {
  const PaymentSent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class _SendAppBar extends StatelessWidget {
  const _SendAppBar();

  @override
  Widget build(BuildContext context) {
    return BBAppBar(
      text: 'Send bitcoin',
      onBack: () {
        context.pop();
      },
    );
  }
}

class SendWalletBalance extends StatelessWidget {
  const SendWalletBalance({super.key});

  @override
  Widget build(BuildContext context) {
    final totalFrozen = context.select(
      (WalletBloc cubit) => cubit.state.wallet?.frozenUTXOTotal() ?? 0,
    );

    if (totalFrozen == 0) {
      final balance = context.select(
        (WalletBloc cubit) => cubit.state.wallet?.fullBalance?.total ?? 0,
      );

      final balStr = context.select(
        (CurrencyCubit cubit) => cubit.state.getAmountInUnits(balance),
      );
      return BBText.body(balStr, isBold: true);
    } else {
      final balanceWithoutFrozenUTXOs = context.select(
        (WalletBloc cubit) =>
            cubit.state.wallet?.balanceWithoutFrozenUTXOs() ?? 0,
      );
      final balStr = context.select(
        (CurrencyCubit cubit) =>
            cubit.state.getAmountInUnits(balanceWithoutFrozenUTXOs),
      );
      final frozenStr = context.select(
        (CurrencyCubit cubit) => cubit.state.getAmountInUnits(totalFrozen),
      );

      return Column(
        children: [
          BBText.bodySmall(balStr),
          const Gap(4),
          BBText.bodySmall('Frozen Balance $frozenStr'),
        ],
      );
    }
  }
}

class TxDetailsScreen extends StatelessWidget {
  const TxDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // final isLn = context.select((SendCubit cubit) => cubit.state.isLnInvoice());

    final addr = context.select((SendCubit cubit) => cubit.state.address);
    // final swapAddress =
    //     context.select((SwapCubit cubit) => cubit.state.swapTx?.scriptAddress);
    // final address = swapAddress ?? addr;

    final amount = context.select((CurrencyCubit cubit) => cubit.state.amount);
    final amtStr = context
        .select((CurrencyCubit cubit) => cubit.state.getAmountInUnits(amount));
    final fee = context
        .select((SendCubit cubit) => cubit.state.psbtSignedFeeAmount ?? 0);
    final feeStr = context
        .select((CurrencyCubit cubit) => cubit.state.getAmountInUnits(fee));

    final currency =
        context.select((CurrencyCubit _) => _.state.defaultFiatCurrency);
    final amtFiat = context.select(
      (NetworkCubit cubit) => cubit.state.calculatePrice(amount, currency),
    );
    final feeFiat = context.select(
      (NetworkCubit cubit) => cubit.state.calculatePrice(fee, currency),
    );

    final fiatCurrency = context.select(
      (CurrencyCubit cubit) => cubit.state.defaultFiatCurrency?.shortName ?? '',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Gap(24),
        const BBText.titleLarge(
          'Confirm Transaction',
        ),
        const Gap(32),
        const BBText.title(
          'Transaction Amount',
        ),
        const Gap(4),
        BBText.bodyBold(
          amtStr,
        ),
        BBText.body(
          '~ $amtFiat $fiatCurrency ',
        ),
        const Gap(24),
        const BBText.title(
          'Recipient Bitcoin Address',
        ),
        const Gap(4),
        BBText.body(addr),
        const Gap(24),
        const BBText.title(
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

// class _LnFeesFromSwapTx extends StatelessWidget {
//   const _LnFeesFromSwapTx();

//   @override
//   Widget build(BuildContext context) {
//     final swapTx = context.select((SwapCubit cubit) => cubit.state.swapTx);
//     if (swapTx == null) return const SizedBox.shrink();

//     final networkFees = swapTx.lockupFees!;
//     final boltzFees = swapTx.boltzFees!;
//     final claimFees = swapTx.claimFees!;

//     final currency =
//         context.select((CurrencyCubit _) => _.state.defaultFiatCurrency);

//     final networkFeesStr = context.select(
//       (CurrencyCubit cubit) => cubit.state.getAmountInUnits(networkFees),
//     );
//     final networkFeesFiat = context.select(
//       (NetworkCubit cubit) => cubit.state.calculatePrice(networkFees, currency),
//     );

//     final boltzFeesStr = context.select(
//       (CurrencyCubit cubit) => cubit.state.getAmountInUnits(boltzFees),
//     );
//     final boltzFeesFiat = context.select(
//       (NetworkCubit cubit) => cubit.state.calculatePrice(boltzFees, currency),
//     );

//     final claimFeesStr = context.select(
//       (CurrencyCubit cubit) => cubit.state.getAmountInUnits(claimFees),
//     );
//     final claimFeesFiat = context.select(
//       (NetworkCubit cubit) => cubit.state.calculatePrice(claimFees, currency),
//     );

//     final fiatCurrency = context.select(
//       (CurrencyCubit cubit) => cubit.state.defaultFiatCurrency?.shortName ?? '',
//     );

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         const BBText.title(
//           'Network Fee',
//         ),
//         const Gap(4),
//         BBText.body(
//           networkFeesStr,
//         ),
//         BBText.body(
//           '~ $networkFeesFiat $fiatCurrency',
//         ),
//         const Gap(32),
//         const BBText.title(
//           'Boltz Fee',
//         ),
//         const Gap(4),
//         BBText.body(
//           boltzFeesStr,
//         ),
//         BBText.body(
//           '~ $boltzFeesFiat $fiatCurrency',
//         ),
//         const Gap(16),
//         const BBText.title(
//           'Claim Fee',
//         ),
//         const Gap(4),
//         BBText.body(
//           claimFeesStr,
//         ),
//         BBText.body(
//           '~ $claimFeesFiat $fiatCurrency',
//         ),
//         const Gap(16),
//         const BBText.title(
//           'Fees Details',
//         ),
//         const Gap(4),
//         const BBText.body(
//           'Exchange Fees = Boltz Fees + Claim Fees',
//         ),
//       ],
//     );
//   }
// }

class TxSuccess extends StatelessWidget {
  const TxSuccess({super.key});

  @override
  Widget build(BuildContext context) {
    final isLn = context.select((SendCubit cubit) => cubit.state.isLnInvoice());
    if (isLn) return const SendingLnTx();

    final amount = context.select((CurrencyCubit cubit) => cubit.state.amount);
    final amtStr = context
        .select((CurrencyCubit cubit) => cubit.state.getAmountInUnits(amount));
    // final tx = context.select((SendCubit cubit) => cubit.state.tx);
    final txid = context.select((SendCubit cubit) => cubit.state.tx!.txid);
    final isLiquid =
        context.select((SendCubit cubit) => cubit.state.tx!.isLiquid);
    return AnnotatedRegion(
      value: const SystemUiOverlayStyle(statusBarColor: Colors.green),
      child: SizedBox(
        height: MediaQuery.of(context).size.height,
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
            InkWell(
              onTap: () {
                final url = context.read<NetworkCubit>().state.explorerTxUrl(
                      txid,
                      isLiquid: isLiquid,
                    );
                locator<Launcher>().launchApp(url);
              },
              child: const BBText.body(
                'View Transaction details ->',
                textAlign: TextAlign.center,
              ),
            ),
            const Gap(24),
            SizedBox(
              height: 52,
              child: TextButton(
                onPressed: () {
                  context.go('/home');
                },
                child: const BBText.titleLarge(
                  'Done',
                  textAlign: TextAlign.center,
                  isBold: true,
                ),
              ),
            ),
          ],
        ).animate().fadeIn(),
      ),
    );
  }
}
