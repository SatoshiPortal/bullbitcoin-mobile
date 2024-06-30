import 'package:bb_arch/_pkg/currency/models/currency.dart';
import 'package:bb_arch/_pkg/fee_rate/models/fee_rate.dart';
import 'package:bb_arch/_pkg/utils.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import 'package:bb_arch/_ui/molecules/fee_rate/fee_rate.dart';

@widgetbook.UseCase(name: 'Default', type: FeeRateSelector)
Widget buildFeeRateSelectorUseCase(BuildContext context) {

  return FeeRateSelector(
    label: 'Select fee rate',
    currentFeeRate: FeeRate(
      fast: context.knobs.int.input(
        label: 'currentFeeRate.fast',
        initialValue: 30,
      ),
      fastest: context.knobs.int.input(
        label: 'currentFeeRate.fastest',
        initialValue: 40,
      ),
      medium: context.knobs.int.input(
        label: 'currentFeeRate.medium',
        initialValue: 20,
      ),
      slow: context.knobs.int.input(
        label: 'currentFeeRate.slow',
        initialValue: 10,
      ),
    ),
    feeRate: context.knobs.int.input(
      label: 'feeRate',
      description: 'The user selected sats/vB',
      initialValue: 20,
    ),
    selectedFeeRate: context.knobs.list(
      label: 'Selected fee rate type',
      options: [
        FeeRateType.fastest,
        FeeRateType.fast,
        FeeRateType.medium,
        FeeRateType.slow,
        FeeRateType.custom,
      ],
      labelBuilder: (value) {
        switch(value) {
          case FeeRateType.fastest:
            return 'Fastest';
          case FeeRateType.fast:
            return 'Fast';
          case FeeRateType.medium:
            return 'Medium';
          case FeeRateType.slow:
            return 'Slow';
          case FeeRateType.custom:
            return 'Custom';
        }
      },
    ),
    onDefaultFeeRateChange: ({required FeeRateType selectedFeeRate, required int updatedDefaultFeeRate}) {
      // TODO: Implement this functions
      print('WidgetCatalog :: FeeRateSelector :: onDefaultFeeRateChange');
      print(selectedFeeRate);
      print(updatedDefaultFeeRate);
    },
  );
}
