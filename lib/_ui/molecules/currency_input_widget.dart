import 'package:bb_mobile/_model/currency_new.dart';
import 'package:bb_mobile/_ui/atoms/bb_form_field.dart';
import 'package:flutter/material.dart';

class CurrencyInput extends StatefulWidget {
  const CurrencyInput({
    super.key,
    required this.currencies,
    required this.unitsInSats,
    this.label,
    this.currency,
    this.onlyCrypto = false, // No FIAT options, display, conversions
    this.showCurrencyLogos = false,
    this.defaultFiat,
    this.disabled = false,
    this.initialPrice,
    this.initialCurrency,
    this.textEditingController,
    this.onChange,
    this.onCurrencyChange,
  });

  final List<CurrencyNew> currencies;
  final CurrencyNew? defaultFiat;
  final bool disabled;
  final bool unitsInSats;
  final String? label;
  final CurrencyNew? currency;
  final bool onlyCrypto;
  final bool showCurrencyLogos;

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
            selectedCurrency =
                widget.currencies[1]; // TODO: Asset this to be sats
          } else {
            selectedCurrency =
                widget.currencies[0]; // TODO: Asset this to be btc
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
  void didUpdateWidget(CurrencyInput oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If currency prop changes wrt currncies, update selectedCurrency accordingly
    if (widget.currency != null && widget.currency != oldWidget.currency) {
      setState(() {
        selectedCurrency = widget.currency!;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    if (widget.textEditingController == null) amountController.dispose();
  }

  void _onPriceChange(double price) {
    // TODO: Bring calculatesSats inside widget file
    // TODO: This will be needed outside as well. So how?
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

    if (!widget.onlyCrypto) {
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
          onChanged: widget.disabled == true
              ? null
              : (String? value) {
                  if (value != null) {
                    final CurrencyNew selectedCurrency =
                        widget.currencies.firstWhere(
                      (currency) => currency.code == value,
                      orElse: () => widget.currencies[0],
                    );
                    _onCurrencyChange(selectedCurrency);
                  }
                },
          items: widget.currencies.map((CurrencyNew currency) {
            final child = widget.showCurrencyLogos
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
          label: widget.label ?? 'Amount',
          editingController: amountController,
          suffix: currencyPicker,
          keyboardType: TextInputType.number,
          disabled: widget.disabled,
        ),
        const SizedBox(
          height: 10,
        ),
        Text(helperText),
      ],
    );
  }
}
