import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/fee_entity.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class BumpFeeSelectorWidget extends StatefulWidget {
  const BumpFeeSelectorWidget({
    super.key,
    required this.fastestFeeRate,
    required this.selected,
    required this.txSize,
    required this.onChanged,
  });

  final FeeEntity fastestFeeRate;
  final FeeEntity selected;
  final int txSize;
  final void Function(FeeEntity fee) onChanged;

  @override
  State<BumpFeeSelectorWidget> createState() => _FeeSelectorWidgetState();
}

class _FeeSelectorWidgetState extends State<BumpFeeSelectorWidget> {
  final _controller = TextEditingController();

  // The user types sat/vByte; we keep the typed double locally for the text
  // field and only convert to RelativeFee (the SDK-native sat/kwu unit) once,
  // when emitting up to the cubit.
  double _customFeeRate = 0;
  String get _customFeeRateString => _customFeeRate.toStringAsFixed(1);

  @override
  void initState() {
    super.initState();
    _customFeeRate = widget.selected.feeRate.satPerVbyte;
    _controller.text = _customFeeRateString;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onCustomChanged(String text) {
    final parsed = num.tryParse(text);
    if (parsed != null) {
      _customFeeRate = parsed.toDouble();
      widget.onChanged(
        FeeEntity(
          type: FeeType.custom,
          feeRate: NetworkFee.relativeFromSatPerVbyte(_customFeeRate),
        ),
      );
    } else {
      _customFeeRate = 0;
      _controller.text = '';
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            const Gap(16),
            _buildFastestSection(widget.selected.type == FeeType.fastest),
            const Gap(16),
            _buildCustomFeeSection(widget.selected.type == FeeType.custom),
          ],
        ),
      ),
    );
  }

  Widget _buildFastestSection(bool isSelected) {
    return InkWell(
      radius: 2,
      onTap: () => widget.onChanged(widget.fastestFeeRate),
      child: Material(
        elevation: isSelected ? 4 : 1,
        borderRadius: BorderRadius.circular(2),
        clipBehavior: .hardEdge,
        color: context.appColors.onSecondary,
        shadowColor: context.appColors.secondary,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: .spaceBetween,
            crossAxisAlignment: .start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: .stretch,
                  children: [
                    BBText(
                      context.loc.replaceByFeeFastestTitle,
                      style: context.font.headlineLarge,
                    ),
                    const Gap(4),
                    BBText(
                      context.loc.replaceByFeeFastestDescription,
                      style: context.font.labelMedium,
                    ),
                    const Gap(2),
                    BBText(
                      context.loc.replaceByFeeFeeRateDisplay(
                        widget.fastestFeeRate.feeRate.satPerVbyte
                            .toStringAsFixed(1),
                      ),
                      style: context.font.labelMedium,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.radio_button_checked_outlined,
                color:
                    isSelected
                        ? context.appColors.primary
                        : context.appColors.surface,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomFeeSection(bool isSelected) {
    return InkWell(
      radius: 2,
      onTap:
          () => widget.onChanged(
            FeeEntity(
              type: FeeType.custom,
              feeRate: NetworkFee.relativeFromSatPerVbyte(_customFeeRate),
            ),
          ),
      child: Material(
        elevation: isSelected ? 4 : 1,
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
                mainAxisAlignment: .spaceBetween,
                crossAxisAlignment: .start,
                children: [
                  BBText(
                    context.loc.replaceByFeeCustomFeeTitle,
                    style: context.font.headlineLarge,
                  ),
                  Icon(
                    Icons.radio_button_checked_outlined,
                    color:
                        isSelected
                            ? context.appColors.primary
                            : context.appColors.surface,
                  ),
                ],
              ),
              const Gap(8),
              BBInputText(
                controller: _controller,
                value: _controller.text,
                onChanged: _onCustomChanged,
                onlyNumbers: true,
                rightIcon: Text(
                  context.loc.replaceByFeeSatsVbUnit,
                  style: context.font.bodySmall,
                ),
              ),
              if (_customFeeRate > 0 && _customFeeRate < 0.1) ...[
                const Gap(8),
                BBText(
                  context.loc.sendBelowMinFeeRateError,
                  style: context.font.labelMedium?.copyWith(
                    color: context.appColors.error,
                  ),
                ),
              ] else if (_customFeeRate >= 0.1 && _customFeeRate < 1.0) ...[
                const Gap(8),
                BBText(
                  context.loc.sendSubSatVbyteWarning,
                  style: context.font.labelMedium?.copyWith(
                    color: context.appColors.warning,
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
