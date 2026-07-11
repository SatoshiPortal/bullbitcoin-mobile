import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/dialpad/dial_pad.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/feerate_preset_l10n.dart';
import 'package:bb_mobile/features/sp/presentation/sp_send_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_send_state.dart';
import 'package:bb_mobile/features/sp/presentation/sp_state.dart';
import 'package:bb_mobile/features/sp/router.dart';
import 'package:bb_mobile/features/sp/ui/widgets/sp_send_appbar_progress.dart';
import 'package:bb_mobile/features/sp/ui/widgets/sp_send_error_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SpSendAmountScreen extends StatefulWidget {
  const SpSendAmountScreen({super.key});

  @override
  State<SpSendAmountScreen> createState() => _SpSendAmountScreenState();
}

class _SpSendAmountScreenState extends State<SpSendAmountScreen> {
  // The amount lives in SpSendState.amountSat; the dialpad edits it as a digit
  // string derived from that single value.
  String _digitsOf(BigInt? sats) =>
      (sats == null || sats == BigInt.zero) ? '' : sats.toString();

  void _onDigit(String digit) {
    final cubit = context.read<SpSendCubit>();
    if (cubit.state.isMax) return;
    cubit.setAmount(BigInt.parse(_digitsOf(cubit.state.amountSat) + digit));
  }

  void _onBackspace() {
    final cubit = context.read<SpSendCubit>();
    if (cubit.state.isMax) return;
    final current = _digitsOf(cubit.state.amountSat);
    if (current.isEmpty) return;
    final next = current.substring(0, current.length - 1);
    cubit.setAmount(next.isEmpty ? BigInt.zero : BigInt.parse(next));
  }

  void _submit() {
    final cubit = context.read<SpSendCubit>();
    FocusScope.of(context).unfocus();
    if (cubit.state.isMax) {
      // bwk drains all coins and computes the amount; no manual validation.
      _prepareAndAdvance(cubit);
      return;
    }
    final sats = cubit.state.amountSat;
    if (sats == null) return;
    // Validates against the available balance and surfaces an inline error;
    // only advance to prepare() when the amount is acceptable.
    if (cubit.setValidatedAmount(sats)) {
      _prepareAndAdvance(cubit);
    }
  }

  Future<void> _prepareAndAdvance(SpSendCubit cubit) async {
    await cubit.prepare();
    if (!mounted) return;
    // Advance only when a simulation was produced; on failure the inline error
    // stays on this page.
    if (cubit.state.hasTxSimulation) {
      context.pushNamed(SpRoute.spSendConfirm.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.loc.amountLabel, style: context.font.headlineMedium),
          bottom: SpSendAppBarProgress(
            isLoading: context.select((SpSendCubit c) => c.state.isLoading),
          ),
        ),
        body: SafeArea(
          child: ScrollableColumn(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Gap(16),
                  Text(
                    context.loc.spSendAmountFieldLabel,
                    style: context.font.bodyMedium,
                  ),
                  const Gap(8),
                  BlocSelector<SpSendCubit, SpSendState, (BigInt?, bool)>(
                    selector: (s) => (s.amountSat, s.isMax),
                    builder: (context, value) {
                      final (amount, isMax) = value;
                      final text = isMax
                          ? context.loc.spSendAmountMax
                          : (_digitsOf(amount).isEmpty
                                ? '0'
                                : amount.toString());
                      return Center(
                        child: Text(text, style: context.font.displaySmall),
                      );
                    },
                  ),
                  const Gap(8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: BlocSelector<SpCubit, SpState, SpBalance?>(
                          selector: (s) => s.balance,
                          builder: (context, balance) => Text(
                            context.loc.spSendAvailableSats(
                              FormatAmount.satsGrouped(
                                (balance?.totalUnifiedSat ?? BigInt.zero).toInt(),
                              ),
                            ),
                            style: context.font.bodySmall?.copyWith(
                              color: context.appColors.outline,
                            ),
                          ),
                        ),
                      ),
                      BlocSelector<SpSendCubit, SpSendState, bool>(
                        selector: (s) => s.isMax,
                        builder: (context, isMax) => ChoiceChip(
                          label: Text(context.loc.spSendMaxChip),
                          selected: isMax,
                          onSelected: (v) =>
                              context.read<SpSendCubit>().setMax(v),
                          selectedColor: context.appColors.secondary,
                          labelStyle: isMax
                              ? context.font.bodySmall?.copyWith(
                                  color: context.appColors.onSecondary,
                                )
                              : context.font.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const Gap(24),
                  Text(
                    context.loc.spSendFeeRateLabel,
                    style: context.font.bodyMedium,
                  ),
                  const Gap(8),
                  BlocSelector<SpSendCubit, SpSendState, int>(
                    selector: (state) => state.feerate,
                    builder: (context, feerate) => _FeerateSelector(
                      feerate: feerate,
                      onChanged: (v) =>
                          context.read<SpSendCubit>().setFeerate(v),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BlocSelector<SpSendCubit, SpSendState, SpFailure?>(
                    selector: (s) => s.error,
                    builder: (context, failure) =>
                        SpSendErrorText(failure: failure),
                  ),
                  DialPad(
                    onlyDigits: true,
                    onNumberPressed: _onDigit,
                    onBackspacePressed: _onBackspace,
                  ),
                  const Gap(8),
                  BlocSelector<SpSendCubit, SpSendState, (bool, BigInt?, bool)>(
                    selector: (s) => (s.isMax, s.amountSat, s.isLoading),
                    builder: (context, value) {
                      final (isMax, amount, isLoading) = value;
                      final noAmount = _digitsOf(amount).isEmpty;
                      return BBButton.big(
                        label: context.loc.continueButton,
                        onPressed: _submit,
                        disabled: (!isMax && noAmount) || isLoading,
                        bgColor: context.appColors.secondary,
                        textColor: context.appColors.onSecondary,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Fixed presets plus a manual sat/vB entry; deliberately does not query the
// fee-estimation ports (no live estimate on SP yet), so the user picks a rate.
class _FeerateSelector extends StatefulWidget {
  const _FeerateSelector({required this.feerate, required this.onChanged});
  final int feerate;
  final ValueChanged<int> onChanged;

  @override
  State<_FeerateSelector> createState() => _FeerateSelectorState();
}

class _FeerateSelectorState extends State<_FeerateSelector> {
  final _customController = TextEditingController();

  bool get _isPreset =>
      FeeratePreset.values.any((p) => p.satPerVb == widget.feerate);

  @override
  void initState() {
    super.initState();
    // Pre-fill the custom field when the initial feerate isn't a preset.
    if (!_isPreset) _customController.text = widget.feerate.toString();
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _onCustomChanged(String value) {
    final parsed = int.tryParse(value);
    if (parsed != null && parsed > 0) widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: FeeratePreset.values
              .map(
                (preset) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      label: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            preset.label(context),
                            style: context.font.bodySmall,
                          ),
                          Text(
                            context.loc.spSatPerVbValue('${preset.satPerVb}'),
                            style: context.font.bodySmall?.copyWith(
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      selected: widget.feerate == preset.satPerVb,
                      onSelected: (_) {
                        _customController.clear();
                        widget.onChanged(preset.satPerVb);
                      },
                      selectedColor: context.appColors.secondary,
                      labelStyle: widget.feerate == preset.satPerVb
                          ? context.font.bodySmall?.copyWith(
                              color: context.appColors.onSecondary,
                            )
                          : null,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const Gap(8),
        BBInputText(
          controller: _customController,
          value: _customController.text,
          digitsOnly: true,
          hint: context.loc.spSendCustomFeerateHint,
          suffixText: context.loc.spSatPerVbUnit,
          onChanged: _onCustomChanged,
        ),
      ],
    );
  }
}
