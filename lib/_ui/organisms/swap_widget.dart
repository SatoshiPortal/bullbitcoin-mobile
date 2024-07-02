import 'package:bb_mobile/_model/currency_new.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_ui/components/controls.dart';
import 'package:bb_mobile/_ui/molecules/currency_input_widget.dart';
import 'package:bb_mobile/currency/amount_input.dart';
import 'package:flutter/material.dart';

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
  }

  void convertBetweenBTCandSats(
    TextEditingController controller,
    CurrencyNew toCurrency,
  ) {
    final double price = double.tryParse(controller.text) ?? 0.0;

    if (toCurrency.code.contains('sats')) {
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
        const EnterAmount2(),
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

            List<CurrencyNew> fromCurrencies = [];
            List<CurrencyNew> toCurrencies = [];

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
          },
        ),
        CurrencyInput(
          currencies: lBtcCurrencies,
          unitsInSats: true,
          noFiat: true,
          showImages: true,
          textEditingController: fromPriceController,
          onCurrencyChange: (CurrencyNew? value) {
            if (value != null && (fromPriceCurrency.code != value.code)) {
              convertBetweenBTCandSats(fromPriceController, value);

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
          },
        ),

        /*
        Row(
          children: [
            SizedBox(
              width: 250,
              child: TextField(
                keyboardType: TextInputType.number,
                controller: fromPriceController,
              ),
            ),
            DropdownButton<CurrencyNew>(
              value: fromPriceCurrency,
              items: fromPriceCurrencies.map((CurrencyNew currency) {
                return DropdownMenuItem(
                  value: currency,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(currency.code),
                      const SizedBox(
                        width: 10,
                      ),
                      Image.asset(
                        currency.logoPath ?? '',
                        height: 25,
                        width: 25,
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (CurrencyNew? value) {
                if (value != null && (fromPriceCurrency.code != value.code)) {
                  convertBetweenBTCandSats(fromPriceController, value);

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
              },
            ),
          ],
        ),
        */
        const SizedBox(
          height: 15,
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
            DropdownButton<CurrencyNew>(
              value: toPriceCurrency,
              items: toPriceCurrencies.map((CurrencyNew currency) {
                return DropdownMenuItem(
                  value: currency,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(currency.code),
                      const SizedBox(
                        width: 10,
                      ),
                      Image.asset(
                        currency.logoPath ?? '',
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
