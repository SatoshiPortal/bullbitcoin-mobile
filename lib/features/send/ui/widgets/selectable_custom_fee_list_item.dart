import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/amount_input_formatter.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SelectableCustomFeeListItem extends StatefulWidget {
  const SelectableCustomFeeListItem({super.key});

  @override
  State<SelectableCustomFeeListItem> createState() =>
      _SelectableCustomFeeListItemState();
}

class _SelectableCustomFeeListItemState
    extends State<SelectableCustomFeeListItem> {
  late bool _isAbsolute;
  late TextEditingController _controller;
  late NetworkFee? _customFee;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _customFee = context.read<SendCubit>().state.customFee;
    _isAbsolute = _customFee?.isAbsolute ?? true;
    final value = _customFee?.value.toString() ?? '';
    _controller = TextEditingController(text: value);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSwitchChanged(bool newValue) {
    setState(() {
      _isAbsolute = newValue;
    });
    // Clear the custom fee when the switch is changed
    _controller.clear();
    _customFee = null;
  }

  void _onValueChanged(String text) {
    final parsed = num.tryParse(text);
    if (parsed != null) {
      final fee =
          _isAbsolute
              ? NetworkFee.absolute(parsed.toInt())
              : NetworkFee.relative(parsed.toDouble());
      setState(() {
        _customFee = fee;
      });
    } else {
      setState(() {
        _customFee = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCustomFeeSelected = context.select(
      (SendCubit cubit) => cubit.state.selectedFeeOption == FeeSelection.custom,
    );
    final feeOptions = context.read<SendCubit>().state.feeOptions;
    final txSize = context.read<SendCubit>().state.bitcoinTxSize ?? 140;
    final exchangeRate = context.read<SendCubit>().state.exchangeRate;
    final fiatCurrencyCode = context.read<SendCubit>().state.fiatCurrencyCode;
    final fastestAbsValue = (feeOptions?.fastest.value ?? 0) * txSize;
    final economicAbsValue = (feeOptions?.economic.value ?? 0) * txSize;
    final slowAbsValue = (feeOptions?.slow.value ?? 0) * txSize;
    final customAbsValue =
        _customFee == null
            ? 0
            : _customFee is AbsoluteFee
            ? _customFee!.value
            : (_customFee?.value ?? 0) * txSize;
    final fiatEq = ConvertAmount.satsToFiat(
      customAbsValue.toInt(),
      exchangeRate,
    );

    final subtitle1 =
        _customFee == null || feeOptions == null
            ? ''
            : 'Estimated delivery ~ ${customAbsValue >= fastestAbsValue
                ? '10 minutes'
                : customAbsValue >= economicAbsValue
                ? '10-30 minutes'
                : customAbsValue >= slowAbsValue
                ? 'few hours'
                : 'hours to days'}';

    final subtitle2 =
        _customFee == null
            ? ''
            : '${_customFee!.value} ${_isAbsolute ? 'sats' : 'sats/vB'} = $customAbsValue sats (~ $fiatEq $fiatCurrencyCode)';

    Future<void> submitCustomFee() async {
      await context.read<SendCubit>().customFeesChanged(_customFee!);
      // ignore: use_build_context_synchronously
      Navigator.pop(context, 'Custom Fee');
    }

    return InkWell(
      radius: 2,
      onTap: () {
        // Focus on the text field
        _focusNode.requestFocus();
      },
      child: Material(
        elevation: isCustomFeeSelected ? 4 : 1,
        borderRadius: BorderRadius.circular(2),
        clipBehavior: .hardEdge,
        color: context.appColors.onSecondary,
        shadowColor: context.appColors.secondary,
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
                        BBText('Custom Fee', style: context.font.headlineLarge),
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
                    color:
                        isCustomFeeSelected
                            ? context.appColors.primary
                            : context.appColors.surface,
                  ),
                ],
              ),
              const Gap(12),
              Row(
                children: [
                  BBText(
                    _isAbsolute ? 'Absolute fees' : 'Relative fees',
                    style: context.font.bodySmall,
                  ),
                  const Spacer(),
                  Switch(value: _isAbsolute, onChanged: _onSwitchChanged),
                ],
              ),
              const Gap(8),
              TextFormField(
                controller: _controller,
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
                style: context.font.bodyLarge,
                decoration: InputDecoration(
                  fillColor: context.appColors.onPrimary,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(
                      color: context.appColors.secondaryFixedDim,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(
                      color: context.appColors.secondaryFixedDim,
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(
                      color: context.appColors.secondaryFixedDim.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                  hintText:
                      _isAbsolute
                          ? 'Enter absolute fee in sats'
                          : 'Enter relative fee in sats/vB',
                  hintStyle: context.font.bodyMedium?.copyWith(
                    color: context.appColors.outline,
                  ),
                  suffixText: _isAbsolute ? 'sats' : 'sats/vB',
                ),
                onFieldSubmitted: (_) => submitCustomFee(),
                onChanged: _onValueChanged,
              ),
              const Gap(12),
              BBButton.big(
                disabled: _customFee == null,
                label: 'Confirm custom fee',
                onPressed: submitCustomFee,
                bgColor: context.appColors.secondary,
                textColor: context.appColors.onPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
