import 'package:bb_mobile/_model/currency_new.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';

const btcCurrency =
    CurrencyNew(name: 'Bitcoin', price: 0, code: 'BTC', isFiat: false);
const satsCurrency =
    CurrencyNew(name: 'Sats', price: 0, code: 'sats', isFiat: false);

class CurrencyInput extends StatefulWidget {
  const CurrencyInput({
    super.key,
    required this.currencies,
    required this.defaultFiat,
    required this.unitsInSats,
    this.initialPrice,
    this.initialCurrency,
    this.onChange,
  });

  final List<CurrencyNew> currencies;
  final CurrencyNew defaultFiat;
  final bool unitsInSats;

  final double? initialPrice;
  final CurrencyNew? initialCurrency;

  final Function(double sats, CurrencyNew selectedCurrency)? onChange;

  @override
  State<CurrencyInput> createState() => _CurrencyInputState();
}

class _CurrencyInputState extends State<CurrencyInput> {
  TextEditingController priceController = TextEditingController();
  CurrencyNew selectedCurrency = btcCurrency;
  double _sats = 0;

  bool _isProgrammaticChange = false;

  @override
  void initState() {
    super.initState();

    if (widget.initialPrice != null) {
      if (widget.initialCurrency == null) {
        throw Exception(
          'If initialPrice is used, initialCurrency should also be used',
        );
      } else {
        priceController.text = widget.initialPrice!.toString();
      }
    }

    if (widget.initialCurrency != null) {
      if (widget.initialPrice == null) {
        throw Exception(
          'If initialCurrency is used, initialPrice should also be used',
        );
      } else {
        if (widget.initialCurrency!.isFiat) {
          selectedCurrency = widget.initialCurrency!;
        } else {
          if (widget.unitsInSats) {
            selectedCurrency = satsCurrency;
          } else {
            selectedCurrency = btcCurrency;
          }
        }
      }
    } else {
      if (widget.unitsInSats) {
        selectedCurrency = satsCurrency;
      } else {
        selectedCurrency = btcCurrency;
      }
    }

    if (widget.initialPrice != null && widget.initialCurrency != null) {
      _onPriceChange(widget.initialPrice!);
    }

    priceController.addListener(() {
      if (!_isProgrammaticChange) {
        final double price =
            double.tryParse(priceController.text.replaceAll(',', '')) ?? 0.0;
        _onPriceChange(price);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    priceController.dispose();
  }

  void _onPriceChange(double price) {
    final double sats = calcualteSats(price, selectedCurrency);
    setState(() {
      _sats = sats;
    });

    widget.onChange?.call(sats, selectedCurrency);
  }

  void _onCurrencyChange(CurrencyNew currency) {
    double textInputValue = 0;

    if (currency.isFiat) {
      textInputValue = getFiatValueFromSats(_sats, currency);
    } else {
      if (currency.code == 'BTC') {
        textInputValue = _sats / SATS_IN_BTC;
      } else {
        textInputValue = _sats;
      }
    }

    _isProgrammaticChange = true;
    priceController.text = textInputValue.toString();
    _isProgrammaticChange = false;

    setState(() {
      selectedCurrency = currency;
    });

    widget.onChange?.call(_sats, currency);
  }

  @override
  Widget build(BuildContext context) {
    String helperText = '';
    if (selectedCurrency.isFiat) {
      // Display BTC or Sats in the helper
      if (widget.unitsInSats) {
        helperText = '= $_sats sats';
      } else {
        helperText = '= ${_sats / SATS_IN_BTC} BTC';
      }
    } else {
      // Display default FIAT
      final double fiatValue = getFiatValueFromSats(_sats, widget.defaultFiat);

      helperText = '= $fiatValue ${widget.defaultFiat.code}';
    }

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: TextFormField(
                controller: priceController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  if (selectedCurrency.code == 'sats')
                    CurrencyTextInputFormatter.currency(
                      decimalDigits: 0,
                      enableNegative: false,
                      symbol: '',
                    ),
                ],
              ),
            ),
            const SizedBox(
              width: 20,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: DropdownButton<String>(
                value: selectedCurrency.code,
                onChanged: (String? value) {
                  if (value != null) {
                    final CurrencyNew selectedCurrency =
                        widget.currencies.firstWhere(
                      (currency) => currency.code == value,
                      orElse: () => btcCurrency,
                    );
                    _onCurrencyChange(selectedCurrency);
                  }
                },
                items: widget.currencies.map((CurrencyNew currency) {
                  return DropdownMenuItem<String>(
                    value: currency.code,
                    child: Text(currency.code),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        const SizedBox(
          height: 10,
        ),
        Text(helperText),
      ],
    );
  }
}
