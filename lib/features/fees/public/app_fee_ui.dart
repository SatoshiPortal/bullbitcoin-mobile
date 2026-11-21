import 'package:primitives/primitives.dart' show ConvertAmount, FormatAmount;
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:fees_feature/fee_ui.dart';
import 'package:bull_ui/bull_ui.dart';

const appFeeUi = FeeUi(
  label: _label,
  formatSats: FormatAmount.sats,
  formatApproximateSats: FormatAmount.satsApprox,
  satsToFiat: ConvertAmount.satsToFiat,
);

String _label(BuildContext context, FeeLabel label) => switch (label) {
  FeeLabel.doneButton => context.loc.doneButton,
  FeeLabel.feePrioritySlow => context.loc.feePrioritySlow,
  FeeLabel.sendAbsoluteFees => context.loc.sendAbsoluteFees,
  FeeLabel.sendBelowMinFeeRateError => context.loc.sendBelowMinFeeRateError,
  FeeLabel.sendCustomFee => context.loc.sendCustomFee,
  FeeLabel.sendEconomyFee => context.loc.sendEconomyFee,
  FeeLabel.sendEnterAbsoluteFee => context.loc.sendEnterAbsoluteFee,
  FeeLabel.sendEnterRelativeFee => context.loc.sendEnterRelativeFee,
  FeeLabel.sendEstimatedDelivery => context.loc.sendEstimatedDelivery,
  FeeLabel.sendEstimatedDelivery10Minutes =>
    context.loc.sendEstimatedDelivery10Minutes,
  FeeLabel.sendEstimatedDelivery10to30Minutes =>
    context.loc.sendEstimatedDelivery10to30Minutes,
  FeeLabel.sendEstimatedDeliveryHours => context.loc.sendEstimatedDeliveryHours,
  FeeLabel.sendEstimatedDeliveryHoursToDays =>
    context.loc.sendEstimatedDeliveryHoursToDays,
  FeeLabel.sendFastFee => context.loc.sendFastFee,
  FeeLabel.sendRelativeFees => context.loc.sendRelativeFees,
  FeeLabel.sendSats => context.loc.sendSats,
  FeeLabel.sendSatsPerVB => context.loc.sendSatsPerVB,
  FeeLabel.sendSelectNetworkFee => context.loc.sendSelectNetworkFee,
  FeeLabel.sendSubSatVbyteWarning => context.loc.sendSubSatVbyteWarning,
};
