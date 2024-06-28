import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_ui/components/controls.dart';
import 'package:flutter/material.dart';

const SATS_IN_BTC = 100000000;

class Currency {
  Currency({
    required this.name,
    required this.imagePath,
  });

  final String name;
  final String imagePath;
}

final btcCurrencies = [
  Currency(name: 'BTC', imagePath: 'assets/images/icon_btc.png'),
  Currency(name: 'sats', imagePath: 'assets/images/icon_btc.png'),
];

final lBtcCurrencies = [
  Currency(name: 'L-BTC', imagePath: 'assets/images/icon_lbtc.png'),
  Currency(name: 'L-sats', imagePath: 'assets/images/icon_lbtc.png'),
];

enum CurrencyType { bitcoin, liquidBitcoin }

class SwapWidget extends StatefulWidget {
  const SwapWidget({super.key, required this.wallets});

  final List<Wallet> wallets;

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

  Currency fromPriceCurrency = lBtcCurrencies[0];
  Currency toPriceCurrency = btcCurrencies[0];

  List<Currency> fromPriceCurrencies = lBtcCurrencies;
  List<Currency> toPriceCurrencies = btcCurrencies;

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
  }

  void convertBetweenBTCandSats(
    TextEditingController controller,
    Currency toCurrency,
  ) {
    final double price = double.tryParse(controller.text) ?? 0.0;

    if (toCurrency.name.contains('sats')) {
      // Convert to sats
      controller.text = (price * SATS_IN_BTC).toString();
    } else {
      // Convert to BTC
      controller.text = (price / SATS_IN_BTC).toStringAsFixed(8);
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
              wallet: (label: wallet.name!, enabled: true),
          },
          onChanged: (Wallet wallet) {
            List<Wallet> toWalletsLocal = [];
            Wallet? selectedToWalletLocal;

            List<Currency> fromCurrencies = [];
            List<Currency> toCurrencies = [];

            if (wallet.isLiquid()) {
              toWalletsLocal =
                  widget.wallets.where((w) => !w.isLiquid()).toList();
              selectedToWalletLocal = widget.wallets[1];

              fromCurrencies = lBtcCurrencies;
              toCurrencies = btcCurrencies;
            } else {
              toWalletsLocal = [widget.wallets[0]];
              selectedToWalletLocal = toWalletsLocal[0];

              fromCurrencies = btcCurrencies;
              toCurrencies = lBtcCurrencies;
            }

            final isSat = fromPriceCurrency.name.contains('sats');

            setState(() {
              selectedFromWallet = wallet;
              selectedToWallet = selectedToWalletLocal!;
              toWallets = toWalletsLocal;

              fromPriceCurrencies = fromCurrencies;
              toPriceCurrencies = toCurrencies;

              fromPriceCurrency = fromCurrencies[isSat ? 1 : 0];
              toPriceCurrency = toCurrencies[isSat ? 1 : 0];
            });
          },
        ),
        Row(
          children: [
            SizedBox(
              width: 250,
              child: TextField(
                keyboardType: TextInputType.number,
                controller: fromPriceController,
              ),
            ),
            DropdownButton<Currency>(
              value: fromPriceCurrency,
              items: fromPriceCurrencies.map((Currency currency) {
                return DropdownMenuItem(
                  value: currency,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(currency.name),
                      const SizedBox(
                        width: 10,
                      ),
                      Image.asset(
                        currency.imagePath,
                        height: 25,
                        width: 25,
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (Currency? value) {
                if (value != null && (fromPriceCurrency.name != value.name)) {
                  convertBetweenBTCandSats(fromPriceController, value);

                  final isSat = value.name.contains('sats');
                  final isLiquid = value.name.startsWith('L-');

                  Currency toPriceCurrencyLocal;

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
              },
            ),
          ],
        ),
        const SizedBox(
          height: 75,
        ),
        const Text('Swap to'),
        BBDropDown<Wallet>(
          value: selectedToWallet,
          items: {
            for (final wallet in toWallets)
              wallet: (label: wallet.name!, enabled: true),
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
        Row(
          children: [
            SizedBox(
              width: 250,
              child: TextField(
                keyboardType: TextInputType.number,
                controller: toPriceController,
                enabled: false,
              ),
            ),
            DropdownButton<Currency>(
              value: toPriceCurrency,
              items: toPriceCurrencies.map((Currency currency) {
                return DropdownMenuItem(
                  value: currency,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(currency.name),
                      const SizedBox(
                        width: 10,
                      ),
                      Image.asset(
                        currency.imagePath,
                        height: 25,
                        width: 25,
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: null,
            ),
          ],
        ),
      ],
    );
  }
}
