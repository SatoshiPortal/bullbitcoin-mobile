import 'package:exchange/exchange.dart';
import 'package:transactions/src/presentation/transactions_localizations_x.dart';
import 'package:flutter/widgets.dart';

/// User-facing label for an order's payment method. [OrderPaymentMethod.value]
/// is the exchange's wire string and is parsed back from the API, so it stays
/// as sent; only the label shown to the user is replaced where the wire string
/// names a third-party trademark.
extension OrderPaymentMethodL10n on OrderPaymentMethod {
  String toTranslated(BuildContext context) => switch (this) {
    OrderPaymentMethod.eTransfer =>
      '${context.loc.recipientsTypeInteracEmail} (CAD)',
    _ => value,
  };
}
