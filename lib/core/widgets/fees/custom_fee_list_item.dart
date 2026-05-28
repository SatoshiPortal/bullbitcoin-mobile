import 'dart:async';

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/inputs/amount_input_formatter.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

/// Reusable "Custom Fee" tile used inside the fee-selection modal of both
/// Send and Swap, and as the inline custom-rate tile in RBF. Owns the
/// local edit state (controller, focus, in-progress parsed fee) and lifts
/// state changes out via callbacks — the caller wires those to its
/// cubit/bloc.
///
/// **No explicit Confirm button.** Typing IS the selection: each keystroke
/// fires [onArm] (modal mode) or [onCommit] (RBF mode). In modal mode,
/// the final apply happens at the parent's level when the user dismisses
/// the bottom sheet — see `SendCubit.finalizeArmedCustomFee` and the
/// equivalent `TransferEvent.customFeeFinalized` event for swap.
///
/// **No predictions.** The preview line never computes `rate × vsize`
/// math itself. In modal mode it shows a shimmer while a real PSBT is
/// built (via [onPreview], debounced) and renders the actual
/// `psbt.fee()` value once [previewFeeSat] arrives from the caller's
/// cubit/bloc. If [previewFeeSat] is null and [previewLoading] is
/// false (e.g. user hasn't typed yet), nothing is shown.
///
/// Visual selection rule: `isCommittedAsCustom || _focusNode.hasFocus`.
/// Focus highlights the tile the instant the user taps anywhere on it
/// (the InkWell calls `requestFocus`).
class CustomFeeListItem extends StatefulWidget {
  const CustomFeeListItem({
    super.key,
    required this.initialFee,
    required this.isCommittedAsCustom,
    required this.feePresets,
    required this.txSize,
    required this.exchangeRate,
    required this.fiatCurrencyCode,
    required this.defaultAbsolute,
    required this.tileColor,
    required this.tileShadowColor,
    required this.unselectedIconColor,
    required this.onCommit,
    this.onArm,
    this.onPreview,
    this.previewFeeSat,
    this.previewLoading = false,
    this.allowAbsoluteToggle = true,
    this.commitOnChange = false,
  });

  /// The currently committed `customFee` from the caller's state. Used to
  /// seed the input field on first build.
  final NetworkFee? initialFee;

  /// Whether the caller's `selectedFeeOption == FeeSelection.custom`. Drives
  /// the radio icon / elevation when not in a focused-edit state.
  final bool isCommittedAsCustom;

  /// The preset fees, used to label the "Estimated delivery" subtitle by
  /// comparing the user's value against fastest/economic/slow thresholds.
  final FeeOptions? feePresets;

  /// Estimated tx vsize (vbytes). Used to convert relative → absolute for
  /// the preview line, and to convert absolute → rate for the sub-1 sat/vB
  /// warning logic.
  final int txSize;

  final double exchangeRate;
  final String fiatCurrencyCode;

  /// Initial value of the abs/rel toggle when [initialFee] is null. Send
  /// uses relative, swap uses absolute — historical inconsistency preserved
  /// for now; unify in a separate pass if desired.
  final bool defaultAbsolute;

  // Theme overrides — Send and Swap modals use different surface colors.
  final Color tileColor;
  final Color tileShadowColor;
  final Color unselectedIconColor;

  /// Called on every valid keystroke when [commitOnChange] is true (RBF
  /// mode — the parent takes whatever the latest commit is). In modal
  /// mode (commitOnChange=false), commit happens at the parent level
  /// when the user dismisses the sheet — this callback is unused at the
  /// widget level. The contract: there is no explicit "Confirm" button
  /// anywhere; typing is the selection signal, dismissal is the apply.
  final Future<void> Function(NetworkFee fee) onCommit;

  /// Modal mode only ([commitOnChange] = false). Called on every valid
  /// keystroke so the caller can light up the tile in its state container
  /// without triggering a heavy rebuild — see [SendCubit.armCustomFee].
  /// Idempotent on the caller side. Ignored in RBF mode.
  final void Function(NetworkFee fee)? onArm;

  /// When false, hide the absolute/relative toggle. Input is treated as
  /// relative (sat/vByte) only. RBF passes false — its fee API is
  /// rate-only.
  final bool allowAbsoluteToggle;

  /// When true, call [onCommit] on every valid keystroke instead of
  /// [onArm]. RBF passes true — its parent screen takes whatever the
  /// latest commit is.
  final bool commitOnChange;

  /// Modal mode. Called on a debounced pause (~350 ms after the last
  /// keystroke) so the caller can build a real unsigned PSBT at the
  /// typed rate and report back via [previewFeeSat] / [previewLoading].
  /// Ignored in RBF mode (commitOnChange=true) — RBF parents track the
  /// rate on every keystroke and don't need a separate preview path.
  final void Function(NetworkFee fee)? onPreview;

  /// Real previewed fee (from an unsigned PSBT build, `psbt.fee()` =
  /// Σ inputs − Σ outputs). Null while the preview is in flight or
  /// when no preview has been built yet. The widget never falls back
  /// to local arithmetic — when this is null and [previewLoading] is
  /// false, no preview line is shown.
  final int? previewFeeSat;

  /// True while the caller is building a preview PSBT for the latest
  /// typed rate. The preview line renders a shimmer placeholder.
  final bool previewLoading;

  @override
  State<CustomFeeListItem> createState() => _CustomFeeListItemState();
}

class _CustomFeeListItemState extends State<CustomFeeListItem> {
  late bool _isAbsolute;
  late TextEditingController _controller;
  NetworkFee? _customFee;
  late FocusNode _focusNode;

  /// Debounces the preview-build trigger in modal mode. Per keystroke we
  /// fire [onArm] synchronously (cheap state update), then after this
  /// pause [onPreview] runs — the caller builds a real unsigned PSBT at
  /// the typed rate and reports the actual fee back via
  /// [CustomFeeListItem.previewFeeSat]. Never doing `rate × vsize` math
  /// ourselves was the whole point of the rework: BDK pays 1-3 sats more
  /// at sub-1 sat/vByte due to ceil + sub-dust change absorption, and
  /// the vsize coin selection picks isn't the wallet's worst-case.
  Timer? _previewDebounce;
  static const _previewDebounceDuration = Duration(milliseconds: 350);

  @override
  void initState() {
    super.initState();
    // Prefill from [initialFee] when present so reopening the modal
    // shows the value the user previously committed instead of an empty
    // field. The sat/kwu round-trip drifts by up to 0.002 sat/vB for
    // unusual rates (e.g. 0.55 → 0.552), well below any meaningful UX
    // threshold; for the rates users actually type (0.1, 0.2, 0.5, 1, 2,
    // …) it's exact. The toggle picks the variant that matches the
    // committed fee — falls back to [defaultAbsolute] only when nothing
    // is committed yet.
    final committed = widget.initialFee;
    final useAbsolute = widget.allowAbsoluteToggle &&
        (committed is AbsoluteFee ||
            (committed == null && widget.defaultAbsolute));
    _isAbsolute = useAbsolute;
    _customFee = committed;
    _controller = TextEditingController(
      text: _formatForInput(committed, asAbsolute: useAbsolute),
    );
    _focusNode = FocusNode()..addListener(_onFocusChanged);
  }

  /// Renders a committed fee back into the same string format the input
  /// accepts. Returns '' when there's nothing to show. Kept short and
  /// deliberate — the input formatter trims trailing zeros, so a typed
  /// "0.50" round-trips back as "0.5"; that's fine and matches user
  /// expectations for the rates we support.
  static String _formatForInput(NetworkFee? fee, {required bool asAbsolute}) {
    if (fee == null) return '';
    if (asAbsolute) {
      if (fee is AbsoluteFee) return fee.sats.toString();
      return '';
    }
    if (fee is RelativeFee) {
      final v = fee.satPerVbyte;
      // Strip trailing zeros — "0.50" → "0.5", "1.00" → "1".
      var s = v.toStringAsFixed(2);
      if (s.contains('.')) {
        s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
      }
      return s;
    }
    return '';
  }

  @override
  void didUpdateWidget(CustomFeeListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the caller's selection moved off custom (e.g. user tapped a preset
    // while this tile held focus), drop the focus so the visual highlight
    // collapses to single-selection — otherwise both tiles would appear
    // active until focus naturally moved.
    if (oldWidget.isCommittedAsCustom && !widget.isCommittedAsCustom) {
      if (_focusNode.hasFocus) _focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Visual highlight follows focus — see the class doc.
  void _onFocusChanged() => setState(() {});

  void _onSwitchChanged(bool newValue) {
    setState(() => _isAbsolute = newValue);
    _controller.clear();
    _customFee = null;
  }

  void _onValueChanged(String text) {
    final parsed = num.tryParse(text);
    if (parsed != null) {
      final fee = _isAbsolute
          ? NetworkFee.absolute(parsed.toInt())
          : NetworkFee.relativeFromSatPerVbyte(parsed.toDouble());
      setState(() => _customFee = fee);
      if (widget.commitOnChange) {
        // RBF mode — each keystroke is the commit. Parent's onChanged
        // is light (no PSBT build), so no debounce needed.
        widget.onCommit(fee);
      } else {
        // Modal mode: arm immediately for visual selection (cheap —
        // just a cubit emit clears stale preview state). Then debounce
        // the real-PSBT preview build via onPreview; the caller's
        // cubit will populate previewFeeSat/previewLoading and we'll
        // render shimmer-then-real-fee.
        widget.onArm?.call(fee);
        _previewDebounce?.cancel();
        _previewDebounce = Timer(_previewDebounceDuration, () {
          if (!mounted) return;
          widget.onPreview?.call(fee);
        });
      }
    } else {
      setState(() => _customFee = null);
      _previewDebounce?.cancel();
    }
  }

  /// Effective fee rate in sat/vByte from the typed input. Used for the
  /// sub-1 warning, the 0.1 floor, and to bucket the typed value against
  /// preset rates for the "Estimated delivery" subtitle. Returns null
  /// when there's no value or an absolute amount can't be converted
  /// (vsize unknown).
  double? _effectiveSatPerVbyte() => _rateOf(_customFee);

  /// Same conversion logic, applied to any [NetworkFee] — used both for
  /// the user's typed value and for preset rates.
  double? _rateOf(NetworkFee? fee) {
    if (fee == null) return null;
    if (fee is RelativeFee) return fee.satPerVbyte;
    if (fee is AbsoluteFee && widget.txSize > 0) {
      return fee.sats / widget.txSize;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final showAsSelected = widget.isCommittedAsCustom || _focusNode.hasFocus;
    final feeOptions = widget.feePresets;

    // Subtitle1 ("Estimated delivery ~ X minutes") is decided by comparing
    // the user's TYPED RATE against preset rates — no absolute math, no
    // vsize needed. The buckets are: ≥ fastest → 10m, ≥ economic → 30m,
    // ≥ slow → hours, else → hours to days.
    final customRate = _effectiveSatPerVbyte();
    final fastestRate = _rateOf(feeOptions?.fastest);
    final economicRate = _rateOf(feeOptions?.economic);
    final slowRate = _rateOf(feeOptions?.slow);
    final subtitle1 =
        (_customFee == null ||
            feeOptions == null ||
            customRate == null ||
            fastestRate == null ||
            economicRate == null ||
            slowRate == null)
        ? ''
        : 'Estimated delivery ~ ${customRate >= fastestRate
              ? context.loc.sendEstimatedDelivery10Minutes
              : customRate >= economicRate
              ? context.loc.sendEstimatedDelivery10to30Minutes
              : customRate >= slowRate
              ? context.loc.sendEstimatedDeliveryHours
              : context.loc.sendEstimatedDeliveryHoursToDays}';

    // Fee-rate guards. Single source for the floor is
    // NetworkFeeRelayPolicy.minRelaySatPerVbyte (= 0.1, Bitcoin Core's
    // lowest sensible policy and Liquid's minrelayfee). Below 1 sat/vByte
    // we still warn the tx may take longer to confirm and may not
    // propagate to every node.
    final bool belowFloor = customRate != null &&
        customRate < NetworkFeeRelayPolicy.minRelaySatPerVbyte;
    final bool subOneSatPerVbyte =
        customRate != null && customRate < 1.0 && !belowFloor;

    return InkWell(
      radius: 2,
      onTap: () {
        _focusNode.requestFocus();
        // RBF mode: tapping the tile with a prefilled value also commits,
        // so the parent's "current selection" is the rate shown in the
        // input even if the user doesn't type. Matches the pre-refactor
        // RBF behaviour where the tile's InkWell committed on tap.
        if (widget.commitOnChange && _customFee != null && !belowFloor) {
          widget.onCommit(_customFee!);
        }
      },
      child: Material(
        elevation: showAsSelected ? 4 : 1,
        borderRadius: BorderRadius.circular(2),
        clipBehavior: .hardEdge,
        color: widget.tileColor,
        shadowColor: widget.tileShadowColor,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              Row(
                crossAxisAlignment: .start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .stretch,
                      children: [
                        BBText(
                          context.loc.sendCustomFee,
                          style: context.font.headlineLarge,
                        ),
                        if (subtitle1.isNotEmpty) ...[
                          const Gap(4),
                          BBText(subtitle1, style: context.font.labelMedium),
                        ],
                        // Preview line: shimmer while the caller is
                        // building the unsigned PSBT; real fee once
                        // previewFeeSat lands. No prediction math —
                        // when neither loading nor a real fee, hide.
                        if (_customFee != null) ...[
                          const Gap(2),
                          _PreviewLine(
                            customFee: _customFee!,
                            isAbsolute: _isAbsolute,
                            previewFeeSat: widget.previewFeeSat,
                            previewLoading: widget.previewLoading,
                            exchangeRate: widget.exchangeRate,
                            fiatCurrencyCode: widget.fiatCurrencyCode,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Gap(8),
                  Icon(
                    Icons.radio_button_checked_outlined,
                    color: showAsSelected
                        ? context.appColors.primary
                        : widget.unselectedIconColor,
                  ),
                ],
              ),
              if (widget.allowAbsoluteToggle) ...[
                const Gap(12),
                Row(
                  children: [
                    BBText(
                      _isAbsolute
                          ? context.loc.sendAbsoluteFees
                          : context.loc.sendRelativeFees,
                      style: context.font.bodySmall,
                    ),
                    const Spacer(),
                    Switch(value: _isAbsolute, onChanged: _onSwitchChanged),
                  ],
                ),
              ],
              const Gap(8),
              TextFormField(
                controller: _controller,
                focusNode: _focusNode,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: !_isAbsolute,
                ),
                textInputAction: .done,
                inputFormatters: [
                  if (_isAbsolute)
                    FilteringTextInputFormatter.digitsOnly
                  else
                    AmountInputFormatter(BitcoinUnit.btc.code),
                ],
                onChanged: _onValueChanged,
                style: TextStyle(color: context.appColors.onSurface),
                decoration: InputDecoration(
                  fillColor: context.appColors.surfaceContainer,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(color: context.appColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(color: context.appColors.border),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(
                      color: context.appColors.border.withValues(alpha: 0.5),
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                  hintText: _isAbsolute
                      ? context.loc.sendEnterAbsoluteFee
                      : context.loc.sendEnterRelativeFee,
                  hintStyle: context.font.bodyMedium?.copyWith(
                    color: context.appColors.onSurface,
                  ),
                  suffixText: _isAbsolute
                      ? context.loc.sendSats
                      : context.loc.sendSatsPerVB,
                  suffixStyle: context.font.bodyMedium?.copyWith(
                    color: context.appColors.onSurface,
                  ),
                ),
                // Modal mode: Enter / soft-keyboard "Done" dismisses the
                // sheet — the parent then runs finalizeArmedCustomFee
                // (same path as tap-outside / swipe / back / Escape).
                // RBF mode owns its own commit path on every keystroke,
                // so we don't want Enter to pop the parent screen.
                onFieldSubmitted: widget.commitOnChange
                    ? null
                    : (_) => Navigator.maybePop(context),
              ),
              if (subOneSatPerVbyte) ...[
                const Gap(8),
                BBText(
                  context.loc.sendSubSatVbyteWarning,
                  style: context.font.labelMedium?.copyWith(
                    color: context.appColors.warning,
                  ),
                ),
              ],
              if (belowFloor) ...[
                const Gap(8),
                BBText(
                  context.loc.sendBelowMinFeeRateError,
                  style: context.font.labelMedium?.copyWith(
                    color: context.appColors.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The "rate ~ X sats (~ fiat)" preview row. Three states:
/// - [previewLoading] true → shimmer placeholder
/// - [previewFeeSat] non-null → render real fee + fiat conversion
/// - neither → render nothing (no math fallback by design)
class _PreviewLine extends StatelessWidget {
  const _PreviewLine({
    required this.customFee,
    required this.isAbsolute,
    required this.previewFeeSat,
    required this.previewLoading,
    required this.exchangeRate,
    required this.fiatCurrencyCode,
  });

  final NetworkFee customFee;
  final bool isAbsolute;
  final int? previewFeeSat;
  final bool previewLoading;
  final double exchangeRate;
  final String fiatCurrencyCode;

  @override
  Widget build(BuildContext context) {
    final unit = isAbsolute
        ? context.loc.sendSats
        : context.loc.sendSatsPerVB;
    final rateLabel = '${customFee.value} $unit';

    if (previewLoading) {
      return Row(
        children: [
          BBText(rateLabel, style: context.font.labelMedium),
          const Gap(8),
          // Shimmer fills the rest of the line where "~ X sats" would
          // appear once the real fee lands.
          Expanded(
            child: LoadingLineContent(
              padding: EdgeInsets.zero,
              height: 12,
            ),
          ),
        ],
      );
    }

    if (previewFeeSat == null) {
      // No preview built yet (e.g. user just typed but debounce hasn't
      // fired). Show only the rate — never compute a fee ourselves.
      return BBText(rateLabel, style: context.font.labelMedium);
    }

    final showFiat = exchangeRate > 0 && fiatCurrencyCode.isNotEmpty;
    final fiatEq = showFiat
        ? ConvertAmount.satsToFiat(previewFeeSat!, exchangeRate)
        : null;
    final text = StringBuffer()
      ..write(rateLabel)
      ..write(' ~ ')
      ..write(FormatAmount.satsApprox(previewFeeSat!))
      ..write(' ')
      ..write(context.loc.sendSats);
    if (showFiat) {
      text..write(' (~ ')..write(fiatEq)..write(' ')..write(fiatCurrencyCode)..write(')');
    }
    return BBText(text.toString(), style: context.font.labelMedium);
  }
}
