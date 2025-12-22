import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/dropdown/selectable_list.dart';
import 'package:bb_mobile/core/widgets/inputs/amount_input_formatter.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SwapFeeOptionsModal extends StatelessWidget {
  const SwapFeeOptionsModal({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<TransferBloc>();
    final state = bloc.state;
    final feeList = state.bitcoinNetworkFees;
    if (feeList == null) return const SizedBox.shrink();

    final fees = feeList.display(
      state.bitcoinTxSize ?? 140,
      state.exchangeRate ?? 0.0,
      state.fiatCurrencyCode ?? 'CAD',
    );
    final List<SelectableListItem> feeOptions = [
      for (final fee in fees)
        SelectableListItem(
          value: fee.$1,
          title: fee.$1,
          subtitle1: fee.$2,
          subtitle2: fee.$3,
        ),
    ];

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              const Gap(16),
              BBText(
                context.loc.sendSelectNetworkFee,
                style: context.font.headlineMedium,
              ),
              const Gap(16),
              Builder(
                builder: (context) => SelectableList(
                  selectedValue: state.selectedFeeOption.title(),
                  items: feeOptions,
                ),
              ),
              SwapSelectableCustomFeeListItem(
                bloc: bloc,
              ),
              const Gap(24),
            ],
          ),
        ),
      ),
    );
  }
}

class SwapSelectableCustomFeeListItem extends StatefulWidget {
  const SwapSelectableCustomFeeListItem({
    super.key,
    required this.bloc,
  });

  final TransferBloc bloc;

  @override
  State<SwapSelectableCustomFeeListItem> createState() =>
      _SwapSelectableCustomFeeListItemState();
}

class _SwapSelectableCustomFeeListItemState
    extends State<SwapSelectableCustomFeeListItem> {
  late bool _isAbsolute;
  late TextEditingController _controller;
  late NetworkFee? _customFee;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    final state = widget.bloc.state;
    _customFee = state.customFee;
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
    _controller.clear();
    _customFee = null;
  }

  void _onValueChanged(String text) {
    final parsed = num.tryParse(text);
    if (parsed != null) {
      final fee = _isAbsolute
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
    final state = widget.bloc.state;
    final isCustomFeeSelected = state.selectedFeeOption == FeeSelection.custom;
    final feeOptions = state.bitcoinNetworkFees;
    final txSize = state.bitcoinTxSize ?? 140;
    final exchangeRate = state.exchangeRate ?? 0.0;
    final fiatCurrencyCode = state.fiatCurrencyCode ?? 'CAD';
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
      exchangeRate,
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

    final subtitle2 = _customFee == null
        ? ''
        : '${_customFee!.value} ${_isAbsolute ? context.loc.sendSats : context.loc.sendSatsPerVB} = $customAbsValue ${context.loc.sendSats} (~ $fiatEq $fiatCurrencyCode)';

    Future<void> submitCustomFee() async {
      if (_customFee != null) {
        widget.bloc.add(TransferEvent.customFeeChanged(_customFee!));
        if (context.mounted) {
          Navigator.pop(context, context.loc.sendCustomFee);
        }
      }
    }

    return InkWell(
      radius: 2,
      onTap: () {
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
                    color: isCustomFeeSelected
                        ? context.appColors.primary
                        : context.appColors.surface,
                  ),
                ],
              ),
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
                  hintText: _isAbsolute
                      ? context.loc.sendEnterAbsoluteFee
                      : context.loc.sendEnterRelativeFee,
                  hintStyle: context.font.bodyMedium?.copyWith(
                    color: context.appColors.outline,
                  ),
                  suffixText:
                      _isAbsolute ? context.loc.sendSats : context.loc.sendSatsPerVB,
                ),
                onFieldSubmitted: (_) => submitCustomFee(),
                onChanged: _onValueChanged,
              ),
              const Gap(12),
              BBButton.big(
                disabled: _customFee == null,
                label: context.loc.sendConfirmCustomFee,
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

