import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data_display/bull_amount.dart';
import '../data_display/bull_amount_preferences.dart';
import '../theme/bull_theme.dart';
import '../theme/bull_tokens.dart';
import 'bull_amount_input_formatter.dart';
import 'bull_bitcoin_amount_text.dart';

/// An editable amount with a local display unit and a canonical controller.
class BullBitcoinAmountInput extends StatefulWidget {
  const BullBitcoinAmountInput({
    super.key,
    required this.currency,
    required this.amountController,
    required this.amountEquivalent,
    required this.maxLabel,
    required this.switchToBtcLabel,
    required this.switchToSatsLabel,
    this.error,
    this.focusNode,
    this.readOnly = false,
    this.isMax = false,
  }) : assert(currency == 'BTC' || currency == 'sats');

  final String currency;
  final TextEditingController amountController;
  final String amountEquivalent;
  final String? error;
  final FocusNode? focusNode;
  final bool readOnly;
  final bool isMax;
  final String maxLabel;
  final String switchToBtcLabel;
  final String switchToSatsLabel;

  @override
  State<BullBitcoinAmountInput> createState() => _BullBitcoinAmountInputState();
}

class _BullBitcoinAmountInputState extends State<BullBitcoinAmountInput> {
  late String _unit;
  late final TextEditingController _display;
  bool _updating = false;
  BullAmountUnit? _globalUnit;
  int? _globalRevision;

  @override
  void initState() {
    super.initState();
    _unit = widget.currency;
    _display = TextEditingController(text: widget.amountController.text);
    _display.addListener(_onDisplayChanged);
    widget.amountController.addListener(_onCanonicalChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final globalUnit = BullAmountPreferencesScope.maybeOf(context)?.defaultUnit;
    final revision = BullAmountPreferencesScope.revisionOf(context);
    if (globalUnit != _globalUnit || revision != _globalRevision) {
      _globalUnit = globalUnit;
      _globalRevision = revision;
      _unit = switch (globalUnit) {
        BullAmountUnit.btc => 'BTC',
        BullAmountUnit.sats => 'sats',
        null => widget.currency,
      };
      // Incomplete/composing text has an empty canonical value and is cleared
      // on a global reset rather than interpreted in the newly selected unit.
      _onCanonicalChanged();
    }
  }

  @override
  void didUpdateWidget(BullBitcoinAmountInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amountController != widget.amountController) {
      oldWidget.amountController.removeListener(_onCanonicalChanged);
      widget.amountController.addListener(_onCanonicalChanged);
    }
    if (oldWidget.currency != widget.currency) {
      _unit = switch (_globalUnit) {
        BullAmountUnit.btc => 'BTC',
        BullAmountUnit.sats => 'sats',
        null => widget.currency,
      };
    }
    if (oldWidget.currency != widget.currency ||
        oldWidget.amountController != widget.amountController) {
      _onCanonicalChanged();
    }
  }

  @override
  void dispose() {
    widget.amountController.removeListener(_onCanonicalChanged);
    _display.removeListener(_onDisplayChanged);
    _display.dispose();
    super.dispose();
  }

  bool get _composing =>
      _display.value.composing.isValid && !_display.value.composing.isCollapsed;

  void _onDisplayChanged() {
    if (_updating) return;
    setState(() {});
    final text = _display.text;
    final sats = BullBitcoinAmountText.parse(text, _unit);
    final invalid = _composing || (text.isNotEmpty && sats == null);
    // An incomplete edit cannot leave a previous amount available to submit.
    final String canonical;
    if (invalid || text.isEmpty) {
      canonical = '';
    } else if (_unit == widget.currency) {
      canonical = text;
    } else if (sats != null) {
      canonical = BullBitcoinAmountText.format(sats, widget.currency);
    } else {
      return;
    }
    if (canonical == widget.amountController.text) return;
    _updating = true;
    widget.amountController.value = TextEditingValue(
      text: canonical,
      selection: TextSelection.collapsed(offset: canonical.length),
    );
    _updating = false;
    // A canonical listener may have synchronously replaced our update.
    if (!invalid && widget.amountController.text != canonical) {
      _onCanonicalChanged();
    }
  }

  void _onCanonicalChanged() {
    if (_updating) return;
    final text = widget.amountController.text;
    final sats = BullBitcoinAmountText.parse(text, widget.currency);
    if (text.isNotEmpty && sats == null && _unit != widget.currency) {
      setState(() => _unit = widget.currency);
    }
    final String display;
    if (text.isEmpty || _unit == widget.currency) {
      display = text;
    } else if (sats != null) {
      display = BullBitcoinAmountText.format(sats, _unit);
    } else {
      return;
    }
    if (_display.text == display) return;
    _updating = true;
    _display.value = TextEditingValue(
      text: display,
      selection: TextSelection.collapsed(offset: display.length),
    );
    _updating = false;
    setState(() {});
  }

  void _toggle() {
    if (_composing) return;
    final text = _display.text;
    final sats = BullBitcoinAmountText.parse(text, _unit);
    if (text.isNotEmpty && sats == null) return;
    final next = _unit == 'BTC' ? 'sats' : 'BTC';
    final String converted;
    if (text.isEmpty) {
      converted = '';
    } else if (sats != null) {
      converted = BullBitcoinAmountText.format(sats, next);
    } else {
      return;
    }
    _updating = true;
    _display.value = TextEditingValue(
      text: converted,
      selection: TextSelection.collapsed(offset: converted.length),
    );
    _updating = false;
    setState(() => _unit = next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.displaySmall?.copyWith(
      fontSize: 36,
      color: theme.colorScheme.secondary,
    );
    return Column(
      children: [
        Text(
          widget.error ?? '',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: widget.error == null
                ? context.bull.transparent
                : theme.colorScheme.error,
          ),
          maxLines: 2,
        ),
        const SizedBox(height: BullSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: widget.isMax
                  ? Text(widget.maxLabel, style: style)
                  : IntrinsicWidth(
                      child: TextField(
                        controller: _display,
                        focusNode: widget.focusNode,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: _unit == 'BTC',
                        ),
                        inputFormatters: [_BitcoinEditingFormatter(_unit)],
                        readOnly: widget.readOnly,
                        style: style,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          hintText: '0',
                        ),
                      ),
                    ),
            ),
            BullAmountUnitToggle(
              text: _unit,
              unit: _unit == 'BTC' ? BullAmountUnit.btc : BullAmountUnit.sats,
              semanticValue:
                  '${widget.isMax ? widget.maxLabel : _display.text} $_unit',
              actionLabel: _unit == 'BTC'
                  ? widget.switchToSatsLabel
                  : widget.switchToBtcLabel,
              onPressed: _toggle,
              style: style,
            ),
          ],
        ),
        const SizedBox(height: BullSpacing.sm),
        Text(
          widget.amountEquivalent.isEmpty ? '' : '~${widget.amountEquivalent}',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Keep IME composition intact and reject truncated pastes rather than
/// silently changing their value.
class _BitcoinEditingFormatter extends TextInputFormatter {
  _BitcoinEditingFormatter(this.unit);

  final String unit;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }
    final formatted = BullAmountInputFormatter(
      unit,
    ).formatEditUpdate(oldValue, newValue);
    final normalized = unit == 'BTC'
        ? newValue.text.replaceAll(',', '.')
        : newValue.text;
    return formatted.text == normalized ? formatted : oldValue;
  }
}
