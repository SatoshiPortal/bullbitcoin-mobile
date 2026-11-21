import 'package:bull_ui/bull_ui.dart';

enum FeeLabel {
  doneButton,
  feePrioritySlow,
  sendAbsoluteFees,
  sendBelowMinFeeRateError,
  sendCustomFee,
  sendEconomyFee,
  sendEnterAbsoluteFee,
  sendEnterRelativeFee,
  sendEstimatedDelivery,
  sendEstimatedDelivery10Minutes,
  sendEstimatedDelivery10to30Minutes,
  sendEstimatedDeliveryHours,
  sendEstimatedDeliveryHoursToDays,
  sendFastFee,
  sendRelativeFees,
  sendSats,
  sendSatsPerVB,
  sendSelectNetworkFee,
  sendSubSatVbyteWarning,
}

class FeeUi {
  final String Function(BuildContext, FeeLabel) label;
  final String Function(int) formatSats;
  final String Function(num) formatApproximateSats;
  final double Function(int, double) satsToFiat;

  const FeeUi({
    required this.label,
    required this.formatSats,
    required this.formatApproximateSats,
    required this.satsToFiat,
  });
}
