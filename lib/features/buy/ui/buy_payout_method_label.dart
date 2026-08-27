import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/widgets.dart';

/// The network a buy pays out over, worded for the user. Shared by the wallet
/// dropdown and the confirmation screen so that the two cannot drift.
String buyPayoutMethodLabel(BuildContext context, {required bool isLiquid}) {
  return isLiquid
      ? context.loc.buyPayoutMethodLiquid
      : context.loc.buyPayoutMethodBitcoin;
}
