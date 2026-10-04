import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:meta/meta.dart';

typedef PaymentRequestParser = Future<PaymentRequest> Function(String data);

/// Validates that [input] is a lightning ADDRESS (LNURL / user@domain), not a
/// bolt11 invoice or any other payment string. Returns the trimmed address when
/// valid, or null otherwise.
class ValidateLightningAddressUsecase {
  final PaymentRequestParser _parse;

  ValidateLightningAddressUsecase({PaymentRequestParser? parse})
    : _parse = parse ?? PaymentRequest.parse;

  @useResult
  Future<String?> execute(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    try {
      final request = await _parse(trimmed);
      return request is LnAddressPaymentRequest ? trimmed : null;
    } on Error {
      rethrow;
    } catch (_) {
      return null;
    }
  }
}
