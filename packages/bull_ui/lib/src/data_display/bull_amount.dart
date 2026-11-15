import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart';
import 'package:primitives/primitives.dart';

import '../../generated/l10n/bull_ui_localizations.dart';
import '../inputs/bull_bitcoin_amount_text.dart';
import '../theme/bull_tokens.dart';
import 'bull_amount_scope.dart';

/// A signed Bitcoin display: magnitude remains a nonnegative domain value.
/// A local denomination belongs only to this mounted element.
class BullAmount extends StatefulWidget {
  const BullAmount({
    super.key,
    required this.magnitude,
    this.isNegative = false,
    this.interactive = true,
    this.overrideHideAmounts = false,
    this.style,
    this.color,
    this.textAlign,
  });

  final Sats magnitude;
  final bool isNegative;
  final bool interactive;
  final bool overrideHideAmounts;
  final TextStyle? style;
  final Color? color;
  final TextAlign? textAlign;

  @override
  State<BullAmount> createState() => _BullAmountState();
}

class _BullAmountState extends State<BullAmount> {
  BitcoinUnit? _override;
  BitcoinUnit? _defaultUnit;
  int? _generation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = BullAmountScope.maybeOf(context);
    final unit = scope?.snapshot.unit;
    final generation = scope?.generation;
    if (unit != _defaultUnit || generation != _generation) _override = null;
    _defaultUnit = unit;
    _generation = generation;
  }

  String _format(BitcoinUnit unit, BullUiLocalizations l10n) {
    final symbols = NumberFormat.decimalPattern(l10n.localeName).symbols;
    final String value;
    if (unit == BitcoinUnit.sats) {
      value = widget.magnitude.value.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => symbols.GROUP_SEP,
      );
    } else {
      var btc = BullBitcoinAmountText.format(widget.magnitude.value, unit);
      if (widget.magnitude.value > BigInt.zero &&
          widget.magnitude.value < BigInt.from(10000000)) {
        final parts = btc.split('.');
        final fraction = parts.length > 1 ? parts[1] : '';
        btc = '${parts[0]}.${fraction.padRight(8, '0')}';
      }
      value = btc.replaceFirst('.', symbols.DECIMAL_SEP);
    }
    final sign = widget.isNegative && widget.magnitude.value > BigInt.zero
        ? symbols.MINUS_SIGN
        : '';
    return '$sign$value ${unit.code}';
  }

  @override
  Widget build(BuildContext context) {
    final scope = BullAmountScope.maybeOf(context);
    final snapshot = scope?.snapshot;
    final unit = _override ?? snapshot?.unit ?? BitcoinUnit.btc;
    final l10n = BullUiLocalizations.of(context);
    final hidden =
        snapshot == null ||
        !snapshot.isReady ||
        (snapshot.hideAmounts && !widget.overrideHideAmounts);
    final text = hidden
        ? '${l10n.amountHidden} ${unit.code}'
        : _format(unit, l10n);
    if (!widget.interactive) {
      return Text(
        text,
        style: widget.style?.copyWith(color: widget.color),
        textAlign: widget.textAlign,
      );
    }
    return BullAmountUnitToggle(
      text: text,
      unit: unit,
      style: widget.style,
      color: widget.color,
      textAlign: widget.textAlign,
      onPressed: snapshot?.isReady == true
          ? () => setState(() {
              _override = unit == BitcoinUnit.btc
                  ? BitcoinUnit.sats
                  : BitcoinUnit.btc;
            })
          : null,
    );
  }
}

/// Shared gestures and accessible unit control for display and editable input.
class BullAmountUnitToggle extends StatefulWidget {
  const BullAmountUnitToggle({
    super.key,
    required this.text,
    required this.unit,
    required this.onPressed,
    this.semanticValue,
    this.style,
    this.color,
    this.textAlign,
  });

  final String text;
  final BitcoinUnit unit;
  final VoidCallback? onPressed;
  final String? semanticValue;
  final TextStyle? style;
  final Color? color;
  final TextAlign? textAlign;

  @override
  State<BullAmountUnitToggle> createState() => _BullAmountUnitToggleState();
}

class _BullAmountUnitToggleState extends State<BullAmountUnitToggle> {
  void _tap() {
    final before = widget.semanticValue ?? widget.text;
    widget.onPressed?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final after = widget.semanticValue ?? widget.text;
      if (after == before) return;
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          after,
          Directionality.of(context),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = BullUiLocalizations.of(context);
    final scope = BullAmountScope.maybeOf(context);
    final ready = scope?.snapshot.isReady == true;
    final VoidCallback? globalAction = ready && scope != null
        ? () => unawaited(scope.changeDefaultUnit(widget.unit))
        : null;
    final style = (widget.style ?? Theme.of(context).textTheme.bodyLarge)
        ?.copyWith(color: widget.color);
    return Semantics(
      container: true,
      button: true,
      enabled: widget.onPressed != null || globalAction != null,
      liveRegion: false,
      label: widget.unit == BitcoinUnit.sats
          ? l10n.amountSwitchToBtc
          : l10n.amountSwitchToSats,
      value: widget.semanticValue ?? widget.text,
      onTap: widget.onPressed == null ? null : _tap,
      onLongPress: globalAction,
      customSemanticsActions: globalAction == null
          ? null
          : {
              CustomSemanticsAction(label: l10n.amountChangeDefaultEverywhere):
                  globalAction,
            },
      excludeSemantics: true,
      child: Tooltip(
        message: l10n.amountGesturesHint,
        triggerMode: TooltipTriggerMode.manual,
        excludeFromSemantics: true,
        child: TextButton(
          onPressed: widget.onPressed == null ? null : _tap,
          onLongPress: globalAction,
          style: TextButton.styleFrom(
            minimumSize: const Size(BullSpacing.xxl, BullSpacing.xxl),
            padding: const EdgeInsets.symmetric(horizontal: BullSpacing.xxs),
            foregroundColor: widget.color ?? style?.color,
            tapTargetSize: MaterialTapTargetSize.padded,
            visualDensity: VisualDensity.standard,
          ),
          child: Text(widget.text, style: style, textAlign: widget.textAlign),
        ),
      ),
    );
  }
}
