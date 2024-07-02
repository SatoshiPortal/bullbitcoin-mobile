import 'package:bb_mobile/_model/currency_new.dart';
import 'package:bb_mobile/_ui/atoms/bb_form_field.dart';
import 'package:flutter/material.dart';

class CurrencyInput extends StatefulWidget {
  const CurrencyInput({
    super.key,
    required this.currencies,
    required this.unitsInSats,
    this.noFiat = false,
    this.showImages = false,
    this.defaultFiat,
    this.initialPrice,
    this.initialCurrency,
    this.textEditingController,
    this.onChange,
    this.onCurrencyChange,
  });

  final List<CurrencyNew> currencies;
  final CurrencyNew? defaultFiat;
  final bool unitsInSats;
  final bool noFiat;
  final bool showImages;

  final double? initialPrice;
  final CurrencyNew? initialCurrency;
  final TextEditingController? textEditingController;

  final Function(int sats, CurrencyNew selectedCurrency)? onChange;
  final Function(CurrencyNew currency)? onCurrencyChange;

  @override
  State<CurrencyInput> createState() => _CurrencyInputState();
}

class _CurrencyInputState extends State<CurrencyInput> {
  late TextEditingController amountController;
  late CurrencyNew selectedCurrency; // = btcCurrency;
  int _sats = 0;

  bool _isProgrammaticChange = false;

  @override
  void initState() {
    super.initState();

    selectedCurrency = widget.currencies[0];

    amountController = widget.textEditingController ?? TextEditingController();

    if (widget.initialPrice != null) {
      if (widget.initialCurrency == null) {
        throw Exception(
          'If initialPrice is used, initialCurrency should also be used',
        );
      } else {
        amountController.text = widget.initialPrice!.toString();
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
            selectedCurrency = widget.currencies[1]; // Assuming this to be sats
          } else {
            selectedCurrency = widget.currencies[0]; // Assuming this to be btc
          }
        }
      }
    } else {
      if (widget.unitsInSats) {
        selectedCurrency = widget.currencies[1];
      } else {
        selectedCurrency = widget.currencies[0];
      }
    }

    if (widget.initialPrice != null && widget.initialCurrency != null) {
      _onPriceChange(widget.initialPrice!);
    }

    amountController.addListener(() {
      if (!_isProgrammaticChange) {
        final double price =
            double.tryParse(amountController.text.replaceAll(',', '')) ?? 0.0;
        _onPriceChange(price);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    if (widget.textEditingController == null) amountController.dispose();
  }

  void _onPriceChange(double price) {
    final int sats = calcualteSats(price, selectedCurrency);
    setState(() {
      _sats = sats;
    });

    widget.onChange?.call(sats, selectedCurrency);
  }

  void _onCurrencyChange(CurrencyNew currency) {
    _isProgrammaticChange = true;
    if (currency.isFiat) {
      amountController.text = getFiatValueFromSats(_sats, currency)
          .toStringAsFixed(FIAT_DECIMAL_POINTS);
    } else {
      if (currency.code == btcCurrency.code ||
          currency.code == lbtcCurrency.code) {
        amountController.text =
            (_sats / SATS_IN_BTC).toStringAsFixed(BTC_DECIMAL_POINTS);
      } else {
        amountController.text = _sats.toString();
      }
    }

    _isProgrammaticChange = false;

    setState(() {
      selectedCurrency = currency;
    });

    widget.onChange?.call(_sats, currency);
    widget.onCurrencyChange?.call(currency);
  }

  @override
  Widget build(BuildContext context) {
    String helperText = '';

    if (!widget.noFiat) {
      if (selectedCurrency.isFiat) {
        // Display BTC or Sats in the helper
        if (widget.unitsInSats) {
          helperText = '= $_sats sats';
        } else {
          helperText =
              '= ${(_sats / SATS_IN_BTC).toStringAsFixed(BTC_DECIMAL_POINTS)} BTC';
        }
      } else {
        // Display default FIAT
        final double fiatValue =
            getFiatValueFromSats(_sats, widget.defaultFiat!);

        helperText =
            '= ${fiatValue.toStringAsFixed(FIAT_DECIMAL_POINTS)} ${widget.defaultFiat!.code}';
      }
    }

    final currencyPicker = Padding(
      padding: const EdgeInsets.only(right: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedCurrency.code,
          onChanged: (String? value) {
            if (value != null) {
              final CurrencyNew selectedCurrency = widget.currencies.firstWhere(
                (currency) => currency.code == value,
                orElse: () => widget.currencies[0],
              );
              _onCurrencyChange(selectedCurrency);
            }
          },
          items: widget.currencies.map((CurrencyNew currency) {
            final child = widget.showImages
                ? Row(
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
                  )
                : Text(currency.code);

            return DropdownMenuItem(
              value: currency.code,
              child: child,
            );
          }).toList(),
        ),
      ),
    );

    return Column(
      children: [
        BBFormField(
          label: 'Amount',
          editingController: amountController,
          suffix: currencyPicker,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(
          height: 10,
        ),
        Text(helperText),
      ],
    );
  }
}
