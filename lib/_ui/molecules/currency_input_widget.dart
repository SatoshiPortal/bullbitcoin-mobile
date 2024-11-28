import 'package:bb_mobile/_model/currency.dart';
import 'package:bb_mobile/_model/currency_new.dart';
import 'package:bb_mobile/_ui/atoms/bb_form_field.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';

/// Constraints: This component always require sats and btc to be first two currencies.
/// This satisfies almost all requirements in app right now.
/// In case, any future requirement needs only fiat currency selection, this can be refactored.
class CurrencyInput extends StatefulWidget {
  CurrencyInput({
    super.key,
    required this.currencies,
    required this.unitsInSats,
    this.sweepLabel,
    this.label,

    /// To use this Widget as a controlled component, this currency is set.
    /// In that case, any changes to currency is synced with internal state variable `selectedCurrency`.
    ///
    /// Otherwise, this is not set and currency is handled with internal state variable `selectedCurrency`.
    this.currency,

    /// When set, No FIAT options, display, conversions are displayed
    this.onlyCrypto = false,

    /// To display currency logos.
    /// currencies[].logoPath should be set.
    this.showCurrencyLogos = false,
    this.hideSweep = false,
    this.defaultFiatCurrency,
    this.disabled = false,
    this.initialPrice,
    this.initialCurrency,
    this.textEditingController,
    this.onChange,
    this.onCurrencyChange,
  })  : assert(
          (initialPrice == null && initialCurrency == null) ||
              (initialPrice != null && initialCurrency != null),
          'initialPrice and initialCurrency should be both set together',
        ),
        assert(
          currencies.length >= 2,
          'Atleast 2 currencies: sats and btc should be present',
        ),
        assert(
          currencies[0].code.toLowerCase().contains('btc'),
          'First currency should always be btc',
        ),
        assert(
          currencies[1].code.toLowerCase().contains('sats'),
          'Second currency should always be sats',
        );

  final List<CurrencyNew> currencies;
  final CurrencyNew? defaultFiatCurrency;
  final bool disabled;
  final bool unitsInSats;
  final String? label;
  final String? sweepLabel;
  final CurrencyNew? currency;
  final bool onlyCrypto;
  final bool showCurrencyLogos;
  final bool hideSweep;

  final double? initialPrice;
  final CurrencyNew? initialCurrency;
  final TextEditingController? textEditingController;

  final Function(int sats, bool sweep, CurrencyNew selectedCurrency)? onChange;
  final Function(CurrencyNew currency)? onCurrencyChange;

  @override
  State<CurrencyInput> createState() => _CurrencyInputState();
}

class _CurrencyInputState extends State<CurrencyInput> {
  late TextEditingController amountController;
  late CurrencyNew selectedCurrency; // = btcCurrency;
  int _sats = 0;
  bool sweep = false;

  bool _isProgrammaticChange = false;

  @override
  void initState() {
    super.initState();

    selectedCurrency = widget.currencies[0];

    amountController = widget.textEditingController ?? TextEditingController();

    if (widget.initialPrice != null) {
      amountController.text = widget.initialPrice!.toString();
    }

    if (widget.initialCurrency != null) {
      if (widget.initialCurrency!.isFiat) {
        selectedCurrency = widget.initialCurrency!;
      } else {
        if (widget.unitsInSats) {
          selectedCurrency =
              widget.currencies[1]; // TODO: Asset this to be sats
        } else {
          selectedCurrency = widget.currencies[0]; // TODO: Asset this to be btc
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

    if (sats != _sats) widget.onChange?.call(sats, false, selectedCurrency);

    setState(() {
      _sats = sats;
      if (sats != 0) sweep = false;
    });
  }

  void _onCurrencyChange(CurrencyNew currency) {
    _isProgrammaticChange = true;
    if (currency.isFiat) {
      amountController.text = getFiatValueFromSats(_sats, currency)
          .toStringAsFixed(Currency.FIAT_DECIMAL_POINTS);
    } else {
      if (currency.code == btcCurrency.code ||
          currency.code == lbtcCurrency.code) {
        amountController.text = (_sats / Currency.SATS_IN_BTC)
            .toStringAsFixed(Currency.BTC_DECIMAL_POINTS);
      } else {
        amountController.text = _sats.toString();
      }
    }

    _isProgrammaticChange = false;

    setState(() {
      selectedCurrency = currency;
    });

    widget.onChange?.call(_sats, sweep, currency);
    widget.onCurrencyChange?.call(currency);
  }

  void _onSweep() {
    setState(() {
      sweep = true;
      _sats = 0;
    });
    amountController.text = '';
    widget.onChange?.call(0, true, selectedCurrency);
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
              '= ${(_sats / Currency.SATS_IN_BTC).toStringAsFixed(Currency.BTC_DECIMAL_POINTS)} BTC';
        }
      } else {
        // Display default FIAT
        final double fiatValue =
            getFiatValueFromSats(_sats, widget.defaultFiatCurrency!);

        helperText =
            '= ${fiatValue.toStringAsFixed(Currency.FIAT_DECIMAL_POINTS)} ${widget.defaultFiatCurrency!.code}';
      }
    }

    final currencyPicker = Padding(
      padding: const EdgeInsets.only(right: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedCurrency.code,
          dropdownColor: context.colour.primaryContainer,
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
          bottomPadding: 0.0,
          placeholderText: sweep == true ? '[Send MAX]' : null,
        ),
        if (widget.hideSweep == false)
          BBButton.text(
            label: widget.sweepLabel ?? 'Sweep',
            onPressed: _onSweep,
            fontSize: 12.0,
          ),
        const SizedBox(
          height: 10,
        ),
        Text(helperText),
      ],
    );
  }
}
