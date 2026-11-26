import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
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
