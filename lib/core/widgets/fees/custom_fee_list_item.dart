import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/amount_input_formatter.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

/// Reusable "Custom Fee" tile used inside the fee-selection modal of both
/// Send and Swap (and, in a follow-up, RBF). Owns the local edit state
/// (controller, focus, in-progress parsed fee) and lifts state changes out
/// via callbacks — the caller wires those to its cubit/bloc.
///
/// Visual selection rule: `isCommittedAsCustom || _focusNode.hasFocus`.
/// Focus highlights the tile the instant the user taps anywhere on it
/// (the InkWell already calls `requestFocus`). [onArm] commits
/// `selectedFeeOption: custom` + the typed fee on the first valid keystroke
/// so the preset tiles deselect cleanly, without triggering a PSBT rebuild.
/// [onCommit] is called on the explicit Confirm button — that's where the
/// rebuild happens. [onDisarm] runs in `dispose`, rolling back the
/// in-flight arm if the user closed the modal without submitting.
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
    this.onDisarm,
    this.onConfirmed,
    this.allowAbsoluteToggle = true,
    this.showConfirmButton = true,
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

  /// Called when the user submits via the Confirm button, or on every
  /// valid keystroke when [commitOnChange] is true (RBF mode). Caller
  /// commits + (for send/swap) rebuilds the PSBT here.
  final Future<void> Function(NetworkFee fee) onCommit;

  /// Modal mode only ([commitOnChange] = false). Called on every valid
  /// keystroke so the caller can light up the tile in its state container
  /// without triggering a heavy rebuild — see [SendCubit.armCustomFee].
  /// Idempotent on the caller side.
  final void Function(NetworkFee fee)? onArm;

  /// Modal mode only. Called from `dispose`. If the user submitted via
  /// Confirm, the caller will have already cleared the arm — no-op.
  /// Otherwise rolls back to the pre-arm selection.
  final VoidCallback? onDisarm;

  /// Called after [onCommit] resolves — typically `Navigator.pop(modalResult)`.
  /// Not used in RBF mode (no Confirm button).
  final VoidCallback? onConfirmed;

  /// When false, hide the absolute/relative toggle. Input is treated as
  /// relative (sat/vByte) only. RBF passes false — its fee API is
  /// rate-only.
  final bool allowAbsoluteToggle;

  /// When false, hide the "Confirm Custom Fee" button. RBF passes false —
  /// confirmation lives on the parent screen.
  final bool showConfirmButton;

  /// When true, call [onCommit] on every valid keystroke instead of
  /// [onArm]. RBF passes true — its parent screen takes whatever the
  /// latest commit is. In this mode [onArm] / [onDisarm] are ignored.
  final bool commitOnChange;

  @override
  State<CustomFeeListItem> createState() => _CustomFeeListItemState();
}

class _CustomFeeListItemState extends State<CustomFeeListItem> {
  late bool _isAbsolute;
  late TextEditingController _controller;
  NetworkFee? _customFee;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _customFee = widget.initialFee;
    _isAbsolute = widget.allowAbsoluteToggle
        ? (_customFee?.isAbsolute ?? widget.defaultAbsolute)
        : false;
    final value = _customFee?.value.toString() ?? '';
    _controller = TextEditingController(text: value);
    _focusNode = FocusNode()..addListener(_onFocusChanged);
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
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    if (!widget.commitOnChange) widget.onDisarm?.call();
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
        // RBF mode — each keystroke is the commit.
        widget.onCommit(fee);
      } else {
        // Modal mode — light up the selection without rebuilding.
        widget.onArm?.call(fee);
      }
    } else {
      setState(() => _customFee = null);
    }
  }

  /// Effective fee rate in sat/vByte from the typed input. Used for the
  /// sub-1 warning and the 0.1 floor. Returns null when there's no value or
  /// an absolute amount can't be converted (vsize unknown).
  double? _effectiveSatPerVbyte() {
    final fee = _customFee;
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
    final txSize = widget.txSize;

    final fastestAbsValue = (feeOptions?.fastest.value ?? 0) * txSize;
    final economicAbsValue = (feeOptions?.economic.value ?? 0) * txSize;
    final slowAbsValue = (feeOptions?.slow.value ?? 0) * txSize;
    final customAbsValue = _customFee == null
        ? 0
        : _customFee is AbsoluteFee
        ? _customFee!.value
        : (_customFee?.value ?? 0) * txSize;
    final fiatEq = ConvertAmount.satsToFiat(
      customAbsValue.toInt(),
      widget.exchangeRate,
    );

    final subtitle1 = _customFee == null || feeOptions == null
        ? ''
        : 'Estimated delivery ~ ${customAbsValue >= fastestAbsValue
              ? context.loc.sendEstimatedDelivery10Minutes
              : customAbsValue >= economicAbsValue
              ? context.loc.sendEstimatedDelivery10to30Minutes
              : customAbsValue >= slowAbsValue
              ? context.loc.sendEstimatedDeliveryFewHours
              : context.loc.sendEstimatedDeliveryHoursToDays}';

    final bool showFiatInPreview =
        widget.exchangeRate > 0 && widget.fiatCurrencyCode.isNotEmpty;
    final subtitle2 = _customFee == null
        ? ''
        : '${_customFee!.value} ${_isAbsolute ? context.loc.sendSats : context.loc.sendSatsPerVB} = ${FormatAmount.satsApprox(customAbsValue)} ${context.loc.sendSats}'
              '${showFiatInPreview ? ' (~ $fiatEq ${widget.fiatCurrencyCode})' : ''}';

    // Fee-rate guards. 0.1 floor = Bitcoin Core's lowest sensible policy and
    // Liquid minrelayfee. Below 1 sat/vByte we warn the tx may take longer
    // to confirm and may not propagate to every node.
    final effectiveRate = _effectiveSatPerVbyte();
    final bool belowFloor = effectiveRate != null && effectiveRate < 0.1;
    final bool subOneSatPerVbyte =
        effectiveRate != null && effectiveRate < 1.0 && !belowFloor;

    Future<void> submitCustomFee() async {
      if (_customFee == null || belowFloor) return;
      await widget.onCommit(_customFee!);
      widget.onConfirmed?.call();
    }

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
                        if (subtitle2.isNotEmpty) ...[
                          const Gap(2),
                          BBText(subtitle2, style: context.font.labelMedium),
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
                onFieldSubmitted: (_) => submitCustomFee(),
                onChanged: _onValueChanged,
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
              if (widget.showConfirmButton) ...[
                const Gap(12),
                BBButton.big(
                  disabled: _customFee == null || belowFloor,
                  label: context.loc.sendConfirmCustomFee,
                  onPressed: submitCustomFee,
                  bgColor: context.appColors.secondary,
                  textColor: context.appColors.onSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
