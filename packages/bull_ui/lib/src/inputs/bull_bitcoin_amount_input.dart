import 'package:bull_ui/generated/l10n/bull_ui_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:primitives/primitives.dart';

import '../data_display/bull_amount.dart';
import '../data_display/bull_amount_scope.dart';
import '../theme/bull_theme.dart';
import '../theme/bull_tokens.dart';
import 'bull_amount_input_formatter.dart';
import 'bull_bitcoin_amount_text.dart';

/// An editable amount with a local display unit and a canonical controller.
class BullBitcoinAmountInput extends StatefulWidget {
  const BullBitcoinAmountInput({
    super.key,
    required this.canonicalUnit,
    required this.amountController,
    required this.amountEquivalent,
    this.error,
    this.focusNode,
    this.readOnly = false,
    this.isMax = false,
  });

  final BitcoinUnit canonicalUnit;
  final TextEditingController amountController;
  final String amountEquivalent;
  final String? error;
  final FocusNode? focusNode;
  final bool readOnly;
  final bool isMax;

  @override
  State<BullBitcoinAmountInput> createState() => _BullBitcoinAmountInputState();
}

class _BullBitcoinAmountInputState extends State<BullBitcoinAmountInput> {
  late BitcoinUnit _unit;
  late final TextEditingController _display;
  bool _updating = false;
  BitcoinUnit? _globalUnit;
  int? _globalRevision;
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;
  bool _pendingGlobalReset = false;

  @override
  void initState() {
    super.initState();
    _unit = widget.canonicalUnit;
    _attachFocusNode(widget.focusNode);
    _display = TextEditingController(text: widget.amountController.text);
    _display.addListener(_onDisplayChanged);
    widget.amountController.addListener(_onCanonicalChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = BullAmountScope.maybeOf(context);
    final globalUnit = scope?.snapshot.unit;
    final revision = scope?.generation;
    if (globalUnit != _globalUnit || revision != _globalRevision) {
      _globalUnit = globalUnit;
      _globalRevision = revision;
      _pendingGlobalReset = true;
      _applyPendingGlobalReset();
    }
  }

  @override
  void didUpdateWidget(BullBitcoinAmountInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _detachFocusNode();
      _attachFocusNode(widget.focusNode);
      _applyPendingGlobalReset();
    }
    if (oldWidget.amountController != widget.amountController) {
      oldWidget.amountController.removeListener(_onCanonicalChanged);
      widget.amountController.addListener(_onCanonicalChanged);
    }
    if (oldWidget.canonicalUnit != widget.canonicalUnit) {
      _unit = _globalUnit ?? widget.canonicalUnit;
    }
    if (oldWidget.canonicalUnit != widget.canonicalUnit ||
        oldWidget.amountController != widget.amountController) {
      _onCanonicalChanged();
    }
  }

  @override
  void dispose() {
    _detachFocusNode();
    widget.amountController.removeListener(_onCanonicalChanged);
    _display.removeListener(_onDisplayChanged);
    _display.dispose();
    super.dispose();
  }

  void _attachFocusNode(FocusNode? node) {
    _ownsFocusNode = node == null;
    _focusNode = node ?? FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  void _detachFocusNode() {
    _focusNode.removeListener(_onFocusChanged);
    if (_ownsFocusNode) _focusNode.dispose();
  }

  void _onFocusChanged() {
    _applyPendingGlobalReset(startingEdit: _focusNode.hasFocus);
  }

  void _applyPendingGlobalReset({bool startingEdit = false}) {
    if (!_pendingGlobalReset ||
        (_focusNode.hasFocus && !startingEdit) ||
        _composing) {
      return;
    }
    final text = _display.text;
    if (!startingEdit &&
        text.isNotEmpty &&
        BullBitcoinAmountText.parse(text, _unit) == null) {
      return;
    }
    _pendingGlobalReset = false;
    final target = _globalUnit ?? widget.canonicalUnit;
    _unit = target;
    _onCanonicalChanged();
    if (mounted) setState(() {});
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
    } else if (_unit == widget.canonicalUnit) {
      canonical = text;
    } else if (sats != null) {
      canonical = BullBitcoinAmountText.format(sats, widget.canonicalUnit);
    } else {
      return;
    }
    if (canonical == widget.amountController.text) {
      _applyPendingGlobalReset();
      return;
    }
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
    _applyPendingGlobalReset();
  }

  void _onCanonicalChanged() {
    if (_updating) return;
    final text = widget.amountController.text;
    final sats = BullBitcoinAmountText.parse(text, widget.canonicalUnit);
    if (text.isNotEmpty && sats == null && _unit != widget.canonicalUnit) {
      setState(() => _unit = widget.canonicalUnit);
    }
    final String display;
    if (text.isEmpty || _unit == widget.canonicalUnit) {
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
    final next = _unit == BitcoinUnit.btc ? BitcoinUnit.sats : BitcoinUnit.btc;
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
                  ? Text(
                      BullUiLocalizations.of(context).amountMax,
                      style: style,
                    )
                  : IntrinsicWidth(
                      child: TextField(
                        controller: _display,
                        focusNode: _focusNode,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: _unit == BitcoinUnit.btc,
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
              text: _unit.code,
              unit: _unit,
              semanticValue:
                  '${widget.isMax ? BullUiLocalizations.of(context).amountMax : _display.text} ${_unit.code}',
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

  final BitcoinUnit unit;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }
    final formatted = BullAmountInputFormatter(
      unit.code,
    ).formatEditUpdate(oldValue, newValue);
    var normalized = unit == BitcoinUnit.btc
        ? newValue.text.replaceAll(',', '.')
        : newValue.text;
    // The shared formatter completes a leading separator: ".01" is "0.01".
    if (unit == BitcoinUnit.btc && normalized.startsWith('.')) {
      normalized = '0$normalized';
    }
    return formatted.text == normalized ? formatted : oldValue;
  }
}
