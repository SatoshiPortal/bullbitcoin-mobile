import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_pkg/bull_bitcoin_api.dart';
import 'package:bb_mobile/_pkg/clipboard.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bb_mobile/_pkg/payjoin/manager.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/_repository/app_wallets_repository.dart';
import 'package:bb_mobile/_repository/network_repository.dart';
import 'package:bb_mobile/_repository/wallet/sensitive_wallet_storage.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/_ui/warning.dart';
import 'package:bb_mobile/currency/amount_input.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_bloc.dart';
import 'package:bb_mobile/network_fees/bloc/networkfees_cubit.dart';
import 'package:bb_mobile/network_fees/popup.dart';
import 'package:bb_mobile/send/advanced.dart';
import 'package:bb_mobile/send/bloc/send_cubit.dart';
import 'package:bb_mobile/send/bloc/send_state.dart';
import 'package:bb_mobile/send/listeners.dart';
import 'package:bb_mobile/send/psbt.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/swap/create_swap_bloc/swap_cubit.dart';
import 'package:bb_mobile/swap/send.dart';
import 'package:bb_mobile/swap/ui_swapwidget/wallet_dropdown.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
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

  late CreateSwapCubit swap;
  late CurrencyCubit currency;

  @override
  void initState() {
    swap = CreateSwapCubit(
      walletSensitiveRepository: locator<WalletSensitiveStorageRepository>(),
      swapBoltz: locator<SwapBoltz>(),
      walletTx: locator<WalletTx>(),
      // homeCubit: context.read<HomeBloc>(),
      appWalletsRepository: locator<AppWalletsRepository>(),
      watchTxsBloc: context.read<WatchTxsBloc>(),
      // networkCubit: context.read<NetworkBloc>(),
      networkRepository: locator<NetworkRepository>(),
    )..fetchFees(context.read<NetworkBloc>().state.networkData.testnet);

    networkFees = NetworkFeesCubit(
      // networkCubit: locator<NetworkCubit>(),
      networkRepository: locator<NetworkRepository>(),
      hiveStorage: locator<HiveStorage>(),
      mempoolAPI: locator<MempoolAPI>(),
      defaultNetworkFeesCubit: context.read<NetworkFeesCubit>(),
    );

    currency = CurrencyCubit(
      hiveStorage: locator<HiveStorage>(),
      bbAPI: locator<BullBitcoinAPI>(),
      defaultCurrencyCubit: context.read<CurrencyCubit>(),
    );

    Wallet? wallet;

    if (widget.walletId != null) {
      wallet =
          context.read<AppWalletsRepository>().getWalletById(widget.walletId!);
    } else {
      final isTestnet = context.read<NetworkRepository>().testnet;
      //  context.read<NetworkCubit>().state.testnet;
      wallet =
          context.read<AppWalletsRepository>().getMainWallets(isTestnet).first;
      // walletBloc = createWalletBloc(wallet);
      // context.read<HomeBloc>().state.getMainWallets(isTestnet).first;
    }

    send = SendCubit(
      walletTx: locator<WalletTx>(),
      barcode: locator<Barcode>(),
      defaultRBF: locator<SettingsCubit>().state.defaultRBF,
      fileStorage: locator<FileStorage>(),
      networkRepository: locator<NetworkRepository>(),
      appWalletsRepository: locator<AppWalletsRepository>(),
      // networkCubit: locator<NetworkCubit>(),
      // networkFeesCubit: networkFees,
      // homeCubit: locator<HomeBloc>(),
      payjoinManager: locator<PayjoinManager>(),
      swapBoltz: locator<SwapBoltz>(),
      // currencyCubit: currency,
      openScanner: widget.openScanner,
      // walletBloc: walletBloc,
      swapCubit: swap,
      oneWallet: widget.walletId != null && wallet != null,
      wallet: wallet,
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
    final sendWalletBloc =
        context.select((SendCubit _) => _.state.selectedWallet);

    if (sendWalletBloc == null) return child;
    return BlocProvider(
      create: (BuildContext context) => createWalletBloc(sendWalletBloc),
      child: child,
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    final signed = context.select((SendCubit cubit) => cubit.state.signed);
    final sent = context.select((SendCubit cubit) => cubit.state.sent);
    final isLn = context.select((SendCubit cubit) => cubit.state.isLnInvoice());
    final isPj = context.select((SendCubit cubit) => cubit.state.hasPjParam());
    final isPayjoinPostSuccess = context.select(
      (SendCubit cubit) => cubit.state.isPayjoinPostSuccess,
    );

    final showWarning =
        context.select((CreateSwapCubit x) => x.state.showWarning());

    final walletIsLiquid = context.select(
      (SendCubit x) => x.state.selectedWallet?.isLiquid() ?? false,
    );

    if (isPayjoinPostSuccess) return const PjSuccess();
    if (sent && isLn) return const SendingLnTx();
    if (sent) return const TxSuccess();

    final potentialonchainSwap = context.select(
      (SendCubit x) => x.state.couldBeOnchainSwap(),
    );

    if (showWarning && !walletIsLiquid && potentialonchainSwap == false) {
      return const _Warnings();
    }

    return ColoredBox(
      color: context.colour.primaryContainer,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Gap(32),
              if (!signed) ...[
                const WalletSelectionDropDown(),
                if (potentialonchainSwap) ...[
                  const Gap(8),
                  const BBText.body(
                    'Onchain swap',
                    textAlign: TextAlign.center,
                  ),
                ],
                const Gap(24),
                const AddressField(),
                const Gap(24),
                const AmountField(),
                if (!isLn) const SendAllOption(),
                const Gap(24),
                if (isPj) const SendPayjoinOption(),
                const Gap(24),
                const DescriptionField(),
                if (!isLn) ...[
                  const Gap(24),
                  const NetworkFees(),
                ],
                const Gap(8),
                const AdvancedOptions(),
              ] else if (!isLn) ...[
                const TxDetailsScreen(),
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

class WalletSelectionDropDown extends StatefulWidget {
  const WalletSelectionDropDown();

  @override
  State<WalletSelectionDropDown> createState() =>
      _WalletSelectionDropDownState();
}

class _WalletSelectionDropDownState extends State<WalletSelectionDropDown> {
  List<Wallet> wallets = [];
  @override
  void initState() {
    final network = context.read<NetworkRepository>().getBBNetwork;
    wallets = context
        .read<AppWalletsRepository>()
        .walletFromNetworkExcludeWatchOnly(network);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final oneWallet = context.select(
      (SendCubit cubit) => cubit.state.oneWallet,
    );

    final _ = context.select((SendCubit cubit) => cubit.state.enabledWallets);

    final selectedWallet =
        context.select((SendCubit _) => _.state.selectedWallet);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: oneWallet ? 0.5 : 1,
      child: IgnorePointer(
        ignoring: oneWallet,
        child: WalletDropDown(
          showSpendableBalance: true,
          items: wallets,
          onChanged: (wallet) {
            final wss = wallets.where((wb) => wb == wallet).toList();
            if (wss.isNotEmpty) {
              final currency = context.read<CurrencyCubit>().state;
              context
                  .read<SendCubit>()
                  .updateWallet(wss[0], currency.amount, currency.unitsInSats);
            }
          },
          value: selectedWallet ?? wallets[0],
        ).animate().fadeIn(),
      ),
    );
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

                  if (!context.mounted) return;
                  context.read<CreateSwapCubit>().clearErrors();
                  context.read<SendCubit>().updateAddress(data);
                },
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                color: context.colour.onPrimaryContainer,
                icon: const FaIcon(FontAwesomeIcons.paste),
              ),
              IconButton(
                onPressed: context.read<SendCubit>().scanAddress,
                icon: FaIcon(
                  FontAwesomeIcons.barcode,
                  color: context.colour.onPrimaryContainer,
                ),
              ),
            ],
          ),
          onChanged: (value) {
            context.read<CreateSwapCubit>().clearErrors();
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

class DescriptionField extends StatelessWidget {
  const DescriptionField({super.key});

  @override
  Widget build(BuildContext context) {
    final note = context.select((SendCubit cubit) => cubit.state.note);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.title('Label'),
        const Gap(4),
        BBTextInput.big(
          hint: 'Enter Label',
          value: note,
          onChanged: (value) {
            context.read<SendCubit>().updateNote(value);
          },
        ),
      ],
    );
  }
}

class NetworkFees extends StatelessWidget {
  const NetworkFees({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final walletSelected = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet != null,
    );

    final isSelectedWalletLiquid = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet?.isLiquid() ?? false,
    );

    final sending = context.select((SendCubit cubit) => cubit.state.sending);

    final isLn = context.select((SendCubit _) => _.state.isLnInvoice());

    final isLiquid =
        context.select((SendCubit cubit) => cubit.state.isLiquidPayment());

    if (isLn || isLiquid || !walletSelected || isSelectedWalletLiquid) {
      return const SizedBox.shrink();
    }

    return AnimatedOpacity(
      opacity: sending ? 0.3 : 1,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        ignoring: sending,
        child: SelectFeesButton(
          label: label,
        ).animate().fadeIn(),
      ),
    );
  }
}

class AdvancedOptions extends StatelessWidget {
  const AdvancedOptions({super.key});

  @override
  Widget build(BuildContext context) {
    final walletSelected = context.select(
      (SendCubit cubit) => cubit.state.selectedWallet != null,
    );
    final sending = context.select((SendCubit _) => _.state.sending);
    final isLn = context.select((SendCubit _) => _.state.isLnInvoice());
    final isLiquid = context.select(
      (SendCubit _) => _.state.selectedWallet?.isLiquid() ?? false,
    );
    final addressReady =
        context.select((SendCubit _) => _.state.address.isNotEmpty);

    if (isLn || !walletSelected || !addressReady || isLiquid == true) {
      return const SizedBox.shrink();
    }

    final text =
        context.select((SendCubit _) => _.state.advancedOptionsButtonText());
    return AnimatedOpacity(
      opacity: sending ? 0.3 : 1,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        ignoring: sending,
        child: Column(
          children: [
            BBButton.text(
              onPressed: () {
                AdvancedOptionsPopUp.openPopup(context);
              },
              label: text,
            ).animate().fadeIn(),
            const Gap(48),
          ],
        ),
      ),
    );
  }
}

class SendErrDisplay extends StatelessWidget {
  const SendErrDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final errSend = context.select((SendCubit cubit) => cubit.state.errors());
    final errSwap =
        context.select((CreateSwapCubit cubit) => cubit.state.err());

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
    //if (!showSend || sent) return const SizedBox.shrink();
    if (sent) return const SizedBox.shrink();

    final generatingInv = context
        .select((CreateSwapCubit cubit) => cubit.state.generatingSwapInv);
    final sendingg = context.select((SendCubit cubit) => cubit.state.sending);
    final sending = generatingInv || sendingg;

    final txLabel = context.select((SendCubit cubit) => cubit.state.note);

    final buttonLabel = context.select(
      (SendCubit cubit) => cubit.state.getSendButtonLabel(sending),
    );

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
              disabled: sending || !showSend, // || !showSend,
              leftIcon: Icons.send,
              onPressed: () async {
                if (sending) return;
                final amt = context.read<CurrencyCubit>().state.amount;
                final feeRate = context
                    .read<NetworkFeesCubit>()
                    .state
                    .selectedOrFirst(true);
                context.read<SendCubit>().processSendButton(
                      txLabel,
                      amt,
                      feeRate,
                    );
              },
              label: buttonLabel,
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
      (WalletBloc cubit) => cubit.state.wallet.frozenUTXOTotal(),
    );
    final isLiq =
        context.select((WalletBloc cubit) => cubit.state.wallet.isLiquid());

    if (totalFrozen == 0) {
      final balance = context.select(
        (WalletBloc cubit) => cubit.state.wallet.fullBalance?.total ?? 0,
      );

      final balStr = context.select(
        (CurrencyCubit cubit) =>
            cubit.state.getAmountInUnits(balance, isLiquid: isLiq),
      );
      return BBText.body(balStr, isBold: true);
    } else {
      final balanceWithoutFrozenUTXOs = context.select(
        (WalletBloc cubit) => cubit.state.wallet.balanceWithoutFrozenUTXOs(),
      );
      final balStr = context.select(
        (CurrencyCubit cubit) => cubit.state
            .getAmountInUnits(balanceWithoutFrozenUTXOs, isLiquid: isLiq),
      );
      final frozenStr = context.select(
        (CurrencyCubit cubit) =>
            cubit.state.getAmountInUnits(totalFrozen, isLiquid: isLiq),
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
      (NetworkBloc cubit) => cubit.state.calculatePrice(amount, currency),
    );
    final feeFiat = context.select(
      (NetworkBloc cubit) => cubit.state.calculatePrice(fee, currency),
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

class PjSuccess extends StatelessWidget {
  const PjSuccess({super.key});

  @override
  Widget build(BuildContext context) {
    final amount = context.select((CurrencyCubit cubit) => cubit.state.amount);
    final amtStr = context.select(
      (CurrencyCubit cubit) => cubit.state.getAmountInUnits(
        amount,
      ),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: double.infinity,
          height: 80,
        ),
        const BBText.body(
          'Payjoin requested',
          textAlign: TextAlign.center,
        ),
        const Gap(16),
        const Icon(Icons.pending_rounded, size: 100, color: Colors.orange),
        const BBText.bodySmall(
          "Waiting for recipient's response to broadcast.",
          textAlign: TextAlign.center,
        ),
        const Gap(16),
        BBText.body(
          amtStr,
          textAlign: TextAlign.center,
        ),
        const Gap(40),
        BBButton.big(
          label: 'Back to home',
          onPressed: () {
            context.pop();
          },
        ),
      ],
    );
  }
}

class TxSuccess extends StatelessWidget {
  const TxSuccess({super.key});

  @override
  Widget build(BuildContext context) {
    final isLn = context.select((SendCubit cubit) => cubit.state.isLnInvoice());
    if (isLn) return const SendingLnTx();
    final isLiquid =
        context.select((SendCubit cubit) => cubit.state.tx!.isLiquid);

    final amount = context.select((CurrencyCubit cubit) => cubit.state.amount);
    final amtStr = context.select(
      (CurrencyCubit cubit) => cubit.state.getAmountInUnits(
        amount,
        isLiquid: isLiquid,
      ),
    );
    // final tx = context.select((SendCubit cubit) => cubit.state.tx);
    final tx = context.select((SendCubit _) => _.state.tx);

    return Column(
      // crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: double.infinity,
          height: 80,
        ),

        // const Gap(152),
        // const Icon(Icons.check_circle, size: 120),
        // const Gap(32),
        const BBText.body(
          'Transaction sent',
          textAlign: TextAlign.center,
        ),
        const Gap(16),
        const SendTick(sent: true),
        const Gap(16),
        BBText.body(
          amtStr,
          textAlign: TextAlign.center,
        ),
        const Gap(40),
        if (tx != null)
          BBButton.big(
            label: 'View Transaction',
            onPressed: () {
              context
                ..pop()
                ..push('/tx', extra: [tx, false]);
            },
          ).animate().fadeIn(),
        // const Gap(15),
        // InkWell(
        //   onTap: () {
        //     final url = context.read<NetworkCubit>().state.explorerTxUrl(
        //           txid,
        //           isLiquid: isLiquid,
        //         );
        //     locator<Launcher>().launchApp(url);
        //   },
        //   child: const BBText.body(
        //     'View Transaction details ->',
        //     textAlign: TextAlign.center,
        //   ),
        // ),
        // const Gap(24),
        // SizedBox(
        //   height: 52,
        //   child: TextButton(
        //     onPressed: () {
        //       context.go('/home');
        //     },
        //     child: const BBText.titleLarge(
        //       'Done',
        //       textAlign: TextAlign.center,
        //       isBold: true,
        //     ),
        //   ),
        // ),
      ],
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
          'You are about to send less than 0.01 BTC as a Lightning Network payment using on-chain Bitcoin from your Secure Bitcoin Wallet.',
        ),
        Gap(8),
        BBText.bodySmall(
          'Only do this if you specifically want to send funds from your Secure Bitcoin Wallet.',
          isBold: true,
        ),
        Gap(24),
      ],
    );
  }

  Widget _buildHighFeesWarn({
    required double feePercentage,
    required String amt,
    required String amtFiat,
    required String fees,
    required String feesFiat,
    required String minAmt,
    required String minAmtFiat,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.titleLarge('High fee warning', isRed: true),
        const Gap(8),
        // const BBText.body('Bitcoin Network fees are currently high.'),
        // const Gap(8),
        const BBText.bodySmall(
          'When sending Bitcoin from the Secure Bitcoin Wallet to a Lightning Invoice or Liquid Address, you must pay Bitcoin Network fees and Swap fees.',
        ),
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
            const BBText.bodySmall('Amount you send: '),
            BBText.bodySmall(amt, isBold: true),
          ],
        ),
        Row(
          children: [
            const BBText.bodySmall('Network fees: '),
            BBText.bodySmall(fees, isBold: true),
          ],
        ),
        const Gap(24),
        const BBText.titleLarge('Payment may take many hours', isRed: true),
        const Gap(8),
        const BBText.body(
          'It may take many hours to the recipient to see your payment. Do not continue if recipient requires immediate payment.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final swapTx = context.select((CreateSwapCubit x) => x.state.swapTx);
    if (swapTx == null) return const SizedBox.shrink();

    final errLowAmt =
        context.select((CreateSwapCubit x) => x.state.swapTx!.smallAmt());

    final swaptx = context.select((CreateSwapCubit x) => x.state.swapTx!);

    final errHighFees =
        context.select((CreateSwapCubit x) => x.state.swapTx!.highFees());

    final amt = swaptx.outAmount;

    const minAmt = 1000000;

    final currency =
        context.select((CurrencyCubit _) => _.state.defaultFiatCurrency);

    final fees = swaptx.totalFees() ?? 0;

    final feeStr = context
        .select((CurrencyCubit cubit) => cubit.state.getAmountInUnits(fees));

    final feesFiatStr = context.select(
      (NetworkBloc cubit) => cubit.state.calculatePrice(fees, currency),
    );

    final amtStr = context
        .select((CurrencyCubit cubit) => cubit.state.getAmountInUnits(amt));

    final amtFiatStr = context.select(
      (NetworkBloc cubit) => cubit.state.calculatePrice(amt, currency),
    );

    final minAmtStr = context
        .select((CurrencyCubit cubit) => cubit.state.getAmountInUnits(minAmt));

    final minAmtFiatStr = context.select(
      (NetworkBloc cubit) => cubit.state.calculatePrice(minAmt, currency),
    );

    // final minAmtFiat = context.select(
    //   (NetworkCubit cubit) =>
    //       cubit.state.calculatePrice(minAmt, cubit.state.defaultFiatCurrency!),
    // );
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WarningContainer(
              children: [
                const Gap(24),
                if (errLowAmt) _buildLowAmtWarn(),
                if (errHighFees != null)
                  _buildHighFeesWarn(
                    feePercentage: errHighFees,
                    amt: amtStr,
                    amtFiat: amtFiatStr,
                    fees: feeStr,
                    feesFiat: feesFiatStr,
                    minAmt: minAmtStr,
                    minAmtFiat: minAmtFiatStr,
                    // amt: swapTx.outAmount,
                    // fees: swapTx.totalFees() ?? 0,
                  ),
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
                const Gap(24),
                const Row(
                  children: [
                    Icon(FontAwesomeIcons.lightbulb, size: 32),
                    Gap(8),
                    Expanded(
                      child: BBText.bodySmall(
                        'Pre-fund your Instant Payments Wallet with 0.01 BTC or more and use it as your daily spending account',
                      ),
                    ),
                  ],
                ),
                // const Gap(16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SentPayJoin extends StatelessWidget {
  const SentPayJoin({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
