import 'package:bb_mobile/_model/currency_new.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/molecules/currency_input_widget.dart';
import 'package:bb_mobile/_ui/molecules/wallet/wallet_dropdown.dart';
import 'package:bb_mobile/settings/bloc/lighting_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

const SATS_IN_BTC = 100000000;

final btcCurrencies = [
  btcCurrency,
  satsCurrency,
];

final lBtcCurrencies = [
  lbtcCurrency,
  lsatsCurrency,
];

class SwapWidget2 extends StatefulWidget {
  const SwapWidget2({
    super.key,
    this.loading = false,
    required this.wallets,
    this.onChange,
    this.onSwapPressed,
    this.swapButtonLabel = 'Swap',
    this.swapButtonLoadingLabel = 'Pls wait...',
    this.unitInSats = true,
    this.fee,
    this.feeFiat,
  });

  final bool loading;
  final List<Wallet> wallets;
  final Function(Wallet from, Wallet to, int amount)? onChange;
  final Function(Wallet from, Wallet to, int amount)? onSwapPressed;
  final String swapButtonLabel;
  final String swapButtonLoadingLabel;
  final bool unitInSats;
  final String? fee;
  final String? feeFiat;

  @override
  State<SwapWidget2> createState() => _SwapWidget2State();
}

class _SwapWidget2State extends State<SwapWidget2> {
  List<Wallet> fromWallets = [];
  List<Wallet> toWallets = [];

  late Wallet selectedFromWallet;
  late Wallet selectedToWallet;

  TextEditingController fromPriceController = TextEditingController();
  TextEditingController toPriceController = TextEditingController();

  String fromPrice = '';
  String toPrice = '';

  CurrencyNew fromPriceCurrency = lBtcCurrencies[0];
  CurrencyNew toPriceCurrency = btcCurrencies[0];

  List<CurrencyNew> fromPriceCurrencies = lBtcCurrencies;
  List<CurrencyNew> toPriceCurrencies = btcCurrencies;

  @override
  void initState() {
    super.initState();

    selectedFromWallet = widget.wallets[0];
    selectedToWallet = widget.wallets[1];

    fromWallets = widget.wallets;
    toWallets = widget.wallets.where((wallet) => !wallet.isLiquid()).toList();

    fromPriceController.addListener(() {
      toPriceController.text = fromPriceController.text;
    });

    if (widget.unitInSats) {
      fromPriceCurrency = lBtcCurrencies[1];
      toPriceCurrency = btcCurrencies[1];
    }
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = context.select(
      (Lighting x) => x.state.currentTheme(context) == ThemeMode.dark,
    );

    const imgBaseName = 'assets/images/swap_icon';
    final img = darkMode ? '${imgBaseName}_white.png' : '$imgBaseName.png';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Swap'),
        CurrencyInput(
          currencies: fromPriceCurrencies,
          currency: fromPriceCurrency,
          unitsInSats: widget.unitInSats,
          onlyCrypto: true,
          showCurrencyLogos: true,
          textEditingController: fromPriceController,
          label: '',
          onChange: (sats, selectedCurrency) {
            _onChange(
              selectedFromWallet,
              selectedToWallet,
              sats: sats,
            );
          },
          onCurrencyChange: _fromCurrencyChanged,
          disabled: widget.loading,
        ),
        const Text('From'),
        const SizedBox(
          height: 4,
        ),
        WalletDropDown(
          items: fromWallets,
          onChanged: _fromWalletChanged,
          value: selectedFromWallet,
        ),
        const SizedBox(
          height: 20,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Image.asset(
            img,
            width: 32,
            height: 32,
          ),
        ),
        const Text('To'),
        const SizedBox(
          height: 4,
        ),
        WalletDropDown(
          items: toWallets,
          value: selectedToWallet,
          onChanged: (Wallet wallet) {
            setState(() {
              selectedToWallet = wallet;
            });
            _onChange(
              selectedFromWallet,
              wallet,
            );
          },
        ),
        if (widget.fee != null)
          Align(
            alignment: Alignment.topLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  height: 20,
                ),
                const BBText.title(
                  'Network Fee',
                ),
                const Gap(4),
                BBText.body(
                  widget.fee!,
                ),
                BBText.body(
                  widget.feeFiat!,
                ),
              ],
            ),
          ),
        const Gap(20),
        Align(
          child: BBButton.big(
            label: widget.swapButtonLabel,
            onPressed: _swapButtonPressed,
            loading: widget.loading,
            disabled: widget.loading,
            loadingText: widget.swapButtonLoadingLabel,
          ),
        ),
      ],
    );
  }

  void _swapButtonPressed() {
    print('Swap button pressed');
    if (widget.onSwapPressed != null) {
      final isSat = fromPriceCurrency.code.contains('sats');
      final int sats = isSat
          ? int.parse(fromPriceController.text)
          : (double.parse(fromPriceController.text) * SATS_IN_BTC).toInt();

      widget.onSwapPressed?.call(
        selectedFromWallet,
        selectedToWallet,
        sats,
      );
    }
  }

  void _onChange(Wallet fromWallet, Wallet toWallet, {int? sats}) {
    final isSat = fromPriceCurrency.code.contains('sats');
    final int localSats = isSat
        ? int.parse(fromPriceController.text)
        : (double.parse(fromPriceController.text) * SATS_IN_BTC).toInt();

    widget.onChange?.call(
      fromWallet,
      toWallet,
      sats ?? localSats,
    );
  }

  void _fromCurrencyChanged(CurrencyNew? value) {
    if (value != null && (fromPriceCurrency.code != value.code)) {
      final isSat = value.code.contains('sats');
      final isLiquid = value.code.startsWith('L-');

      CurrencyNew toPriceCurrencyLocal;

      if (isLiquid) {
        if (isSat) {
          toPriceCurrencyLocal = btcCurrencies[1];
        } else {
          toPriceCurrencyLocal = btcCurrencies[0];
        }
      } else {
        if (isSat) {
          toPriceCurrencyLocal = lBtcCurrencies[1];
        } else {
          toPriceCurrencyLocal = lBtcCurrencies[0];
        }
      }

      setState(() {
        fromPriceCurrency = value;
        toPriceCurrency = toPriceCurrencyLocal;
      });
    }
  }

  void _fromWalletChanged(Wallet wallet) {
    List<Wallet> toWalletsLocal = [];
    Wallet? selectedToWalletLocal;

    List<CurrencyNew> fromCurrencies = [];
    List<CurrencyNew> toCurrencies = [];

    if (wallet.isLiquid()) {
      toWalletsLocal = widget.wallets.where((w) => !w.isLiquid()).toList();
      selectedToWalletLocal = widget.wallets[1];

      fromCurrencies = lBtcCurrencies;
      toCurrencies = btcCurrencies;
    } else {
      toWalletsLocal = [widget.wallets[0]];
      selectedToWalletLocal = toWalletsLocal[0];

      fromCurrencies = btcCurrencies;
      toCurrencies = lBtcCurrencies;
    }

    final isSat = fromPriceCurrency.code.contains('sats');

    setState(() {
      selectedFromWallet = wallet;

      selectedToWallet = selectedToWalletLocal!;
      toWallets = toWalletsLocal;

      fromPriceCurrencies = fromCurrencies;
      toPriceCurrencies = toCurrencies;

      fromPriceCurrency = fromCurrencies[isSat ? 1 : 0];
      toPriceCurrency = toCurrencies[isSat ? 1 : 0];
    });

    _onChange(
      wallet,
      selectedToWallet,
    );
  }
}
