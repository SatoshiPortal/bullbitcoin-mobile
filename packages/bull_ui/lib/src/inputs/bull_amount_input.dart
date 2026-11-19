import 'dart:async';
import 'dart:math' as math;

import 'package:bull_ui/generated/l10n/bull_ui_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

import '../data_display/bull_amount.dart';
import '../data_display/bull_amount_scope.dart';
import '../theme/bull_shapes.dart';
import '../theme/bull_theme.dart';
import '../theme/bull_tokens.dart';
import '../theme/bull_typography.dart';
import 'bull_amount_input_formatter.dart';
import 'bull_amount_input_value.dart';
import 'bull_dropdown_menu.dart';
import 'bull_picker_item.dart';

/// One amount editor. The controller is canonical; changing its representation never writes rounded fiat digits back into it. The caller owns prices, validation, Max calculation and the conversion record.
class BullAmountInput extends StatefulWidget {
  const BullAmountInput({
    super.key,
    required this.canonicalUnit,
    required this.amountController,
    this.amountEquivalent = '',
    this.currencies = const [],
    this.defaultCurrencyCode,
    this.initialCurrencyCode,
    this.onEntryChanged,
    this.error,
    this.focusNode,
    this.readOnly = false,
    this.isMax = false,
    this.maxAmountSat,
    this.maxLoading = false,
    this.isLiquid = false,
  });

  final BitcoinUnit canonicalUnit;
  final TextEditingController amountController;
  final String amountEquivalent;
  final List<BullAmountCurrency> currencies;
  final String? defaultCurrencyCode;
  final String? initialCurrencyCode;
  final ValueChanged<BullAmountInputValue>? onEntryChanged;
  final String? error;
  final FocusNode? focusNode;
  final bool readOnly;
  final bool isMax;
  final BigInt? maxAmountSat;
  final bool maxLoading;
  final bool isLiquid;

  @override
  State<BullAmountInput> createState() => _BullAmountInputState();
}

class _BullAmountInputState extends State<BullAmountInput> {
  static const _bitcoinChoice = 'bitcoin';
  static const _defaultChoice = 'initial-mode';
  late BitcoinUnit _unit;
  late final TextEditingController _display;
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;
  bool _updating = false;
  bool _initialized = false;
  bool _preferenceApplied = false;
  bool _userInteracted = false;
  bool _fiatTextEdited = false;
  bool _editedOutOfMax = false;
  bool _pendingGlobalReset = false;
  BitcoinUnit? _globalUnit;
  int? _globalRevision;
  String? _defaultCurrency;
  String? _fiatCurrency;
  String? _lastFiatCurrency;
  String _raw = '';
  String _lastCanonical = '';
  String _observedDisplay = '';
  TextRange _observedComposition = TextRange.empty;
  BigInt? _sats;
  Object? _priceSignature;
  int _notification = 0;
  int _canonicalWrite = 0;

  @override
  void initState() {
    super.initState();
    _unit = widget.canonicalUnit;
    _display = TextEditingController();
    _attachFocusNode(widget.focusNode);
    _syncCanonical(notify: false);
    _display.addListener(_onDisplayChanged);
    widget.amountController.addListener(_onCanonicalChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = BullAmountScope.maybeOf(context);
    _defaultCurrency = widget.currencies.isEmpty
        ? null
        : scope?.snapshot.defaultCurrencyCode ?? widget.defaultCurrencyCode;
    final global = scope?.snapshot.unit;
    final revision = scope?.generation;
    if (!_initialized) {
      _initialized = true;
      _globalUnit = global;
      _globalRevision = revision;
      _unit = widget.isMax ? BitcoinUnit.sats : global ?? widget.canonicalUnit;
      final initial = widget.isMax ? null : widget.initialCurrencyCode;
      _preferenceApplied =
          widget.isMax || (initial != null && initial.isNotEmpty);
      _restoreInitialCurrency(initial);
      _lastFiatCurrency = _fiatCurrency ?? _defaultCurrency;
      _syncCanonical();
    } else if (global != _globalUnit || revision != _globalRevision) {
      _globalUnit = global;
      _globalRevision = revision;
      _pendingGlobalReset = true;
      _applyPendingGlobalReset();
    }
    _tryInitialPreference(scope);
    _refreshPrice();
  }

  void _restoreInitialCurrency(String? code) {
    switch (code) {
      case null || '':
        _fiatCurrency = null;
      case 'BTC' || 'L-BTC':
        _fiatCurrency = null;
        _unit = BitcoinUnit.btc;
      case 'sats' || 'L-sats':
        _fiatCurrency = null;
        _unit = BitcoinUnit.sats;
      case final value:
        _fiatCurrency = value;
    }
  }

  void _tryInitialPreference(BullAmountScopeData? scope) {
    if (_preferenceApplied || _userInteracted || widget.isMax) return;
    final initial = widget.initialCurrencyCode;
    if (initial != null && initial.isNotEmpty) {
      _restoreInitialCurrency(initial);
    } else {
      if (scope != null && !scope.snapshot.isReady) return;
      final fiat = scope?.snapshot.startInFiat == true;
      if (fiat && (widget.currencies.isEmpty || _defaultCurrency == null)) {
        return;
      }
      _fiatCurrency = fiat ? _defaultCurrency : null;
      _unit = _globalUnit ?? widget.canonicalUnit;
    }
    _preferenceApplied = true;
    _lastFiatCurrency = _fiatCurrency ?? _defaultCurrency;
    _syncCanonical();
  }

  @override
  void didUpdateWidget(BullAmountInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _detachFocusNode();
      _attachFocusNode(widget.focusNode);
    }
    if (oldWidget.amountController != widget.amountController) {
      oldWidget.amountController.removeListener(_onCanonicalChanged);
      widget.amountController.addListener(_onCanonicalChanged);
    }
    if (!oldWidget.isMax && widget.isMax) {
      _editedOutOfMax = false;
      _userInteracted = true;
      _fiatCurrency = null;
      _unit = BitcoinUnit.sats;
    }
    final controllerChanged =
        oldWidget.amountController != widget.amountController ||
        oldWidget.canonicalUnit != widget.canonicalUnit;
    final preserveExit =
        oldWidget.isMax &&
        !widget.isMax &&
        _editedOutOfMax &&
        !controllerChanged &&
        widget.amountController.text == _lastCanonical;
    final maxChanged =
        oldWidget.isMax != widget.isMax ||
        oldWidget.maxAmountSat != widget.maxAmountSat ||
        oldWidget.maxLoading != widget.maxLoading;
    if (controllerChanged ||
        (maxChanged && !preserveExit && !_editedOutOfMax)) {
      _syncCanonical();
    }
    if (!widget.isMax) _editedOutOfMax = false;
    _defaultCurrency = widget.currencies.isEmpty
        ? null
        : BullAmountScope.maybeOf(context)?.snapshot.defaultCurrencyCode ??
              widget.defaultCurrencyCode;
    _tryInitialPreference(BullAmountScope.maybeOf(context));
    _refreshPrice();
    _applyPendingGlobalReset();
  }

  @override
  void dispose() {
    _notification++;
    _detachFocusNode();
    widget.amountController.removeListener(_onCanonicalChanged);
    _display.removeListener(_onDisplayChanged);
    _display.dispose();
    super.dispose();
  }

  BullAmountCurrency? _currency(String? code) =>
      widget.currencies.where((currency) => currency.code == code).firstOrNull;
  String? get _equivalentCode => _lastFiatCurrency ?? _defaultCurrency;
  BullAmountCurrency? get _price => _currency(_fiatCurrency ?? _equivalentCode);
  bool get _composing =>
      _display.value.composing.isValid && !_display.value.composing.isCollapsed;
  bool get _showMax => widget.isMax && !_editedOutOfMax;
  bool get _canChangeRepresentation =>
      !_showMax && !_composing && (_raw.isEmpty || _sats != null);
  bool get _canRecoverBitcoin => !_composing && _missingPrice;
  bool get _missingPrice => _fiatCurrency != null && _price?.hasPrice != true;
  String get _shown => _display.text.isNotEmpty
      ? _display.text
      : _showMax && (widget.maxLoading || widget.maxAmountSat == null)
      ? '—'
      : '0';
  String get _unitCode => _fiatCurrency ?? _bitcoinCode(_unit);
  String _bitcoinCode(BitcoinUnit unit) => widget.isLiquid
      ? (unit == BitcoinUnit.btc ? 'L-BTC' : 'L-sats')
      : unit.code;

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
    if (!_composing) _showRaw();
    _applyPendingGlobalReset(startingEdit: _focusNode.hasFocus);
    if (mounted) setState(() {});
  }

  void _applyPendingGlobalReset({bool startingEdit = false}) {
    if (!_pendingGlobalReset ||
        (_focusNode.hasFocus && !startingEdit) ||
        _composing) {
      return;
    }
    if (!startingEdit && _raw.isNotEmpty && _sats == null) return;
    _pendingGlobalReset = false;
    _unit = _showMax ? BitcoinUnit.sats : _globalUnit ?? widget.canonicalUnit;
    if (_fiatCurrency == null) _syncCanonical();
    if (mounted) setState(() {});
  }

  String _group(String text) {
    final parts = text.split('.');
    parts[0] = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return parts.join('.');
  }

  void _showRaw() {
    final text = _focusNode.hasFocus ? _raw : _group(_raw);
    _updating = true;
    _display.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _observedDisplay = text;
    _observedComposition = TextRange.empty;
    _updating = false;
  }

  void _setRaw(String text) {
    _raw = text;
    _showRaw();
  }

  BigInt? _parseBitcoin(String text, BitcoinUnit unit) =>
      Sats.tryParseBitcoin(text, unit)?.value;
  String _bitcoinText(BigInt sats, BitcoinUnit unit) =>
      Sats(sats).toBitcoinText(unit);

  String? _fiatText(BigInt sats, BullAmountCurrency? currency) {
    final rate = currency?.price;
    if (currency == null || !currency.hasPrice || rate == null) return null;
    return Sats(sats).toFiatText(rate, decimals: currency.decimals);
  }

  BigInt? _parseFiat(String text, BullAmountCurrency? currency) {
    final rate = currency?.price;
    if (currency?.hasPrice != true || rate == null) return null;
    return Sats.tryFromFiat(text, rate)?.value;
  }

  void _refreshPrice() {
    final price = _price;
    final signature = (
      price?.code,
      price?.hasPrice == true ? price?.price : null,
      price?.hasPrice == true ? price?.priceAt : null,
      price?.decimals,
      price?.loading,
    );
    if (signature == _priceSignature) return;
    _priceSignature = signature;
    if (_fiatCurrency != null && price?.hasPrice == true) {
      if (_fiatTextEdited && _raw.isNotEmpty && !_composing) {
        _sats = _parseFiat(_raw, price);
        _writeCanonical(defer: true);
        _notify(isEdit: true, defer: true);
        return;
      }
      final sats = _sats;
      if (!_fiatTextEdited && sats != null) {
        _setRaw(_fiatText(sats, price) ?? '');
      }
    }
    _notify(defer: true);
  }

  void _syncCanonical({bool notify = true}) {
    _canonicalWrite++;
    final canonical = widget.amountController.text;
    _fiatTextEdited = false;
    _lastCanonical = canonical;
    _sats = _showMax && (widget.maxLoading || widget.maxAmountSat == null)
        ? null
        : _showMax && widget.maxAmountSat != null
        ? widget.maxAmountSat
        : _parseBitcoin(canonical, widget.canonicalUnit);
    final sats = _sats;
    if (sats == null) {
      if (_fiatCurrency == null && canonical.isNotEmpty && !widget.isMax) {
        _unit = widget.canonicalUnit;
        _setRaw(canonical);
      } else {
        _setRaw('');
      }
    } else if (_fiatCurrency == null) {
      _setRaw(_bitcoinText(sats, _unit));
    } else {
      _setRaw(_fiatText(sats, _price) ?? '');
    }
    if (notify) _notify(defer: true);
  }

  void _onCanonicalChanged() {
    if (_updating || widget.amountController.text == _lastCanonical) return;
    _syncCanonical();
    if (mounted) setState(() {});
  }

  void _writeCanonical({bool defer = false}) {
    final revision = ++_canonicalWrite;
    if (defer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && revision == _canonicalWrite) _writeCanonical();
      });
      return;
    }
    final sats = _sats;
    final canonical = _raw.isEmpty || sats == null
        ? ''
        : _bitcoinText(sats, widget.canonicalUnit);
    _lastCanonical = canonical;
    if (widget.amountController.text == canonical) return;
    _updating = true;
    widget.amountController.value = TextEditingValue(
      text: canonical,
      selection: TextSelection.collapsed(offset: canonical.length),
    );
    _updating = false;
    if (widget.amountController.text != canonical) {
      _syncCanonical(notify: false);
    }
  }

  void _onDisplayChanged() {
    if (_updating) return;
    if (_display.text == _observedDisplay &&
        _display.value.composing == _observedComposition) {
      return;
    }
    _observedDisplay = _display.text;
    _observedComposition = _display.value.composing;
    _userInteracted = true;
    _fiatTextEdited = _fiatCurrency != null;
    if (widget.isMax) _editedOutOfMax = true;
    _raw = _display.text;
    _sats = _composing
        ? null
        : _fiatCurrency == null
        ? _parseBitcoin(_raw, _unit)
        : _parseFiat(_raw, _price);
    _writeCanonical();
    _notify(isEdit: true);
    _applyPendingGlobalReset();
    if (mounted) setState(() {});
  }

  void _notify({bool isEdit = false, bool defer = false}) {
    final callback = widget.onEntryChanged;
    if (callback == null) return;
    final price = _price;
    final value = BullAmountInputValue(
      sats: _sats,
      currencyCode: _unitCode,
      text: _raw,
      price: !isEdit || _fiatCurrency == null || price?.hasPrice != true
          ? null
          : price?.price,
      priceAt: !isEdit || _fiatCurrency == null || price?.hasPrice != true
          ? null
          : price?.priceAt,
      isValid:
          !_composing &&
          !_missingPrice &&
          (!_showMax || (!widget.maxLoading && widget.maxAmountSat != null)) &&
          (_raw.isEmpty || _sats != null),
      isEdit: isEdit,
      isMax: _showMax && !isEdit,
    );
    final notification = ++_notification;
    if (!defer) {
      callback(value);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && notification == _notification) {
          widget.onEntryChanged?.call(value);
        }
      });
    }
  }

  void _toggleUnit() {
    if (!_canChangeRepresentation) return;
    _userInteracted = true;
    _fiatTextEdited = false;
    _unit = _unit == BitcoinUnit.btc ? BitcoinUnit.sats : BitcoinUnit.btc;
    final sats = _sats;
    _setRaw(sats == null ? '' : _bitcoinText(sats, _unit));
    _notify();
    setState(() {});
  }

  void _selectCurrency(String? code) {
    if (!_canChangeRepresentation && !(code == null && _canRecoverBitcoin)) {
      return;
    }
    final currency = _currency(code);
    final sats = _sats;
    if (code != null && currency?.hasPrice != true) return;
    if (code != null && sats != null && _fiatText(sats, currency) == null) {
      return;
    }
    _userInteracted = true;
    _fiatTextEdited = false;
    _fiatCurrency = code;
    if (code != null) _lastFiatCurrency = code;
    _setRaw(
      sats == null
          ? ''
          : code == null
          ? _bitcoinText(sats, _unit)
          : _fiatText(sats, currency) ?? '',
    );
    _priceSignature = null;
    _notify();
    setState(() {});
  }

  Future<void> _openMenu(BuildContext anchor) async {
    final l10n = BullUiLocalizations.of(context);
    final scope = BullAmountScope.maybeOf(context);
    final defaultCurrency = _defaultCurrency;
    final first = _currency(defaultCurrency);
    final ordered = [
      ?first,
      for (final currency in widget.currencies)
        if (currency.code != defaultCurrency) currency,
    ];
    final current = _fiatCurrency ?? _bitcoinChoice;
    final selectedFiat = _fiatCurrency;
    final fiat = selectedFiat != null;
    final selectedLabel = selectedFiat ?? l10n.amountBitcoin;
    final showPreference =
        defaultCurrency != null &&
        scope?.snapshot.isReady == true &&
        scope?.canWriteInputMode == true &&
        (!fiat || _fiatCurrency == defaultCurrency);
    final checked = scope?.snapshot.startInFiat == fiat;
    final items = [
      BullPickerItem(
        value: _bitcoinChoice,
        label: l10n.amountBitcoin,
        enabled: _canChangeRepresentation || _canRecoverBitcoin,
      ),
      for (final currency in ordered)
        BullPickerItem(
          value: currency.code,
          label: currency.code,
          enabled: currency.hasPrice && _canChangeRepresentation,
          disabledReason: currency.hasPrice
              ? (_canChangeRepresentation ? null : l10n.amountIncomplete)
              : currency.loading
              ? l10n.amountLoadingPrice
              : l10n.amountNoPrice,
        ),
      if (showPreference)
        BullPickerItem(
          value: _defaultChoice,
          label: l10n.amountAlwaysStartIn(selectedLabel),
          checked: checked,
          dividerBefore: true,
        ),
    ];
    final chosen = await showBullDropdownMenu(
      anchor: anchor,
      items: items,
      value: current,
    );
    if (!mounted || chosen == null) return;
    final value = items[chosen].value;
    if (value == _defaultChoice) {
      if (scope == null || defaultCurrency == null) return;
      unawaited(
        scope.changeDefaultInputMode(
          checked ? !fiat : fiat,
          bitcoinMessage: l10n.amountStartChanged(l10n.amountBitcoin),
          fiatMessage: l10n.amountStartChanged(defaultCurrency),
          failureMessage: l10n.amountPreferenceChangeFailed,
        ),
      );
    } else {
      _selectCurrency(value == _bitcoinChoice ? null : value);
    }
  }

  String get _equivalent {
    final sats = _sats ?? (_raw.isEmpty && !_showMax ? BigInt.zero : null);
    if (_fiatCurrency != null) {
      final unit = _showMax ? BitcoinUnit.sats : _unit;
      if (_missingPrice || sats == null) {
        return '≈ — ${_bitcoinCode(BitcoinUnit.sats)}';
      }
      return '≈ ${_group(_bitcoinText(sats, unit))} ${_bitcoinCode(unit)}';
    }
    final code = _equivalentCode;
    if (code == null) {
      return widget.amountEquivalent.isEmpty
          ? ''
          : '≈ ${widget.amountEquivalent}';
    }
    final text = sats == null ? null : _fiatText(sats, _price);
    if (text == null) return '≈ — $code';
    // The symbol and currency code carry the equivalent; there is no action on it.
    return '≈ ${_group(text)} $code';
  }

  Widget _numberRow(BuildContext context, String equivalent) {
    final l10n = BullUiLocalizations.of(context);
    final base = context.bullType.display.copyWith(
      fontWeight: FontWeight.w500,
      color: context.bull.text,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        double measure(String text) => (TextPainter(
          text: TextSpan(text: text, style: base),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout()).width;
        final number = _shown;
        final separateIcon =
            _fiatCurrency == null && widget.currencies.isNotEmpty
            ? BullSpacing.xxl
            : BullSpacing.zero;
        final unitPadding =
            BullSpacing.xs +
            (_fiatCurrency == null ? BullSpacing.zero : BullSpacing.lg);
        final available = constraints.maxWidth - separateIcon - BullSpacing.xxs;
        final numberWidth = measure(number);
        final unitWidth = measure(_unitCode);
        final needed = numberWidth + unitWidth;
        var scale = constraints.maxWidth.isFinite && needed > 0
            ? math.min(1.0, math.max(0.0, available - unitPadding) / needed)
            : 1.0;
        if (unitWidth * scale + unitPadding < BullSpacing.xxl &&
            numberWidth > 0) {
          scale = math.min(
            1.0,
            math.max(0.0, available - BullSpacing.xxl) / numberWidth,
          );
        }
        final size = base.fontSize;
        final style = size == null
            ? base
            : base.copyWith(fontSize: size * scale);
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: BullSpacing.xxl),
                child: IntrinsicWidth(
                  child: Semantics(
                    label: '${l10n.amountField} $_unitCode',
                    child: TextField(
                      controller: _display,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: _fiatCurrency == null
                            ? _unit == BitcoinUnit.btc
                            : (_price?.decimals ?? 0) > 0,
                      ),
                      inputFormatters: [
                        BullAmountInputFormatter(
                          _unitCode,
                          maxDecimals: _fiatCurrency == null
                              ? _unit.decimals
                              : _price?.decimals,
                        ),
                      ],
                      readOnly: widget.readOnly,
                      style: style,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                        hintText:
                            _showMax &&
                                (widget.maxLoading ||
                                    widget.maxAmountSat == null)
                            ? '—'
                            : '0',
                        hintStyle: style.copyWith(
                          color: context.bull.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_fiatCurrency == null) ...[
              BullAmountUnitToggle(
                text: _unitCode,
                unit: _unit,
                semanticValue: '$number $_unitCode $equivalent',
                onPressed: _canChangeRepresentation ? _toggleUnit : null,
                style: style,
              ),
              if (widget.currencies.isNotEmpty)
                Builder(
                  builder: (anchor) => IconButton(
                    tooltip: l10n.amountCurrency(l10n.amountBitcoin),
                    onPressed: () => _openMenu(anchor),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: context.bull.text,
                      size: BullSpacing.lg,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: BullSpacing.xxl,
                      minHeight: BullSpacing.xxl,
                    ),
                  ),
                ),
            ] else
              Builder(
                builder: (anchor) => Tooltip(
                  message: l10n.amountCurrency(_unitCode),
                  child: TextButton(
                    onPressed: () => _openMenu(anchor),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(BullSpacing.xxl, BullSpacing.xxl),
                      padding: const EdgeInsets.symmetric(
                        horizontal: BullSpacing.xxs,
                      ),
                      foregroundColor: context.bull.text,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_unitCode, style: style),
                        Icon(
                          Icons.arrow_drop_down,
                          color: context.bull.text,
                          size: BullSpacing.lg,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = BullUiLocalizations.of(context);
    final equivalent = _equivalent;
    final error = _missingPrice ? l10n.amountPriceUnavailable : widget.error;
    final flipTarget = _equivalentCode;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.amountField,
      value: '$_shown $_unitCode $equivalent',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            excluding: error == null,
            child: Semantics(
              liveRegion: error != null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: BullSpacing.xxl),
                child: Text(
                  error ?? '\n',
                  style: context.bullType.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: context.bull.error,
                  ),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          const SizedBox(height: BullSpacing.xs),
          _numberRow(context, equivalent),
          const SizedBox(height: BullSpacing.xxs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  equivalent,
                  style: context.bullType.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: context.bull.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (flipTarget != null)
                IconButton(
                  tooltip: _fiatCurrency == null
                      ? l10n.amountEnterFiat(flipTarget)
                      : l10n.amountEnterBitcoin,
                  onPressed:
                      (!_canChangeRepresentation &&
                              !(_fiatCurrency != null && _canRecoverBitcoin)) ||
                          (_fiatCurrency == null &&
                              _currency(flipTarget)?.hasPrice != true)
                      ? null
                      : () => _selectCurrency(
                          _fiatCurrency == null ? flipTarget : null,
                        ),
                  icon: Icon(
                    Icons.swap_vert,
                    color: context.bull.text,
                    size: BullSpacing.lg,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: BullSpacing.xxl,
                    minHeight: BullSpacing.xxl,
                  ),
                ),
            ],
          ),
          if (_showMax) ...[
            const SizedBox(height: BullSpacing.xxs),
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.bull.text,
                  borderRadius: BorderRadius.circular(
                    context.bullShapes.button,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BullSpacing.xs,
                    vertical: BullSpacing.xxs,
                  ),
                  child: Text(
                    l10n.amountMaxAfterFees,
                    style: context.bullType.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.bull.background,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
