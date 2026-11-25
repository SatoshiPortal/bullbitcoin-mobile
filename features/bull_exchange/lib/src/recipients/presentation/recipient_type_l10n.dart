import 'package:bull_exchange/src/recipients/presentation/payout_rail_l10n.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';

extension RecipientTypeL10n on RecipientType {
  String label(BuildContext context) => rail.label(context);
}
