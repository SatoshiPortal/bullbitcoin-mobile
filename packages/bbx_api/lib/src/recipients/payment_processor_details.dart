import 'package:bbx_api/src/bbx_api_exception.dart';
import 'package:bbx_api/src/json.dart';
import 'package:meta/meta.dart';

/// The funding instructions from `getUserPaymentProcessorCode`: the user's
/// payment processor [element] and the processor's [extraData]
/// (`ppExtraData`). Their keys depend on the payment processor; a missing
/// object is empty.
@immutable
class PaymentProcessorDetails {
  final Map<String, dynamic> element;
  final Map<String, dynamic> extraData;

  const PaymentProcessorDetails({
    this.element = const {},
    this.extraData = const {},
  });

  /// Throws a [BbxApiFormatException] when `element` or `ppExtraData` is not
  /// an object.
  factory PaymentProcessorDetails.fromJson(Map<String, dynamic> json) =>
      PaymentProcessorDetails(
        element:
            read<Map<String, dynamic>?>(json['element'], 'element') ?? const {},
        extraData:
            read<Map<String, dynamic>?>(json['ppExtraData'], 'ppExtraData') ??
            const {},
      );
}
