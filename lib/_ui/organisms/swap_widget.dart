import 'package:bb_mobile/_model/currency_new.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/controls.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/molecules/currency_input_widget.dart';
import 'package:flutter/material.dart';
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

class SwapWidget extends StatefulWidget {
  const SwapWidget({
    super.key,
    this.loading = false,
    required this.wallets,
    this.onSwapPressed,
    this.swapButtonLabel = 'Swap',
    this.swapButtonLoadingLabel = 'Pls wait...',
    this.unitInSats = true,
    this.fee,
    this.feeFiat,
  });

  final bool loading;
  final List<Wallet> wallets;
  final Function(Wallet from, Wallet to, int amount)? onSwapPressed;
  final String swapButtonLabel;
  final String swapButtonLoadingLabel;
  final bool unitInSats;
  final String? fee;
  final String? feeFiat;

  @override
  State<SwapWidget> createState() => _SwapWidgetState();
}

class _SwapWidgetState extends State<SwapWidget> {
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Text('Swap from'),
        BBDropDown<Wallet>(
          value: selectedFromWallet,
          items: {
            for (final wallet in fromWallets)
              wallet: (label: wallet.name!, enabled: true, imagePath: null),
          },
          onChanged: _fromWalletChanged,
        ),
        CurrencyInput(
          currencies: fromPriceCurrencies,
          currency: fromPriceCurrency,
          unitsInSats: widget.unitInSats,
          onlyCrypto: true,
          showCurrencyLogos: true,
          textEditingController: fromPriceController,
          label: '',
          onCurrencyChange: _fromCurrencyChanged,
          disabled: widget.loading,
        ),
        const SizedBox(
          height: 10,
        ),
        const Text('Swap to'),
        BBDropDown<Wallet>(
          value: selectedToWallet,
          items: {
            for (final wallet in toWallets)
              wallet: (label: wallet.name!, enabled: true, imagePath: null),
          },
          // items: toWallets.map((Wallet wallet) {
          //   return DropdownMenuItem(value: wallet, child: Text(wallet.name!));
          // }).toList(),
          onChanged: (Wallet wallet) {
            setState(() {
              selectedToWallet = wallet;
            });
          },
        ),
        CurrencyInput(
          currencies: toPriceCurrencies,
          currency: toPriceCurrency,
          unitsInSats: toPriceCurrency.code.contains('sats'),
          onlyCrypto: true,
          showCurrencyLogos: true,
          textEditingController: toPriceController,
          label: '',
          disabled: true,
        ),
        if (widget.fee != null)
          Align(
            alignment: Alignment.topLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
        BBButton.big(
          label: widget.swapButtonLabel,
          onPressed: _swapButtonPressed,
          loading: widget.loading,
          disabled: widget.loading,
          loadingText: widget.swapButtonLoadingLabel,
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
  }
}
