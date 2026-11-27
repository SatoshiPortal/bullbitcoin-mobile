import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:primitives/primitives.dart';
import 'package:satoshifier/payment_request.dart';

typedef PaymentRequestParser = Future<PaymentRequest> Function(String data);

/// Takes a typed destination only when it is a Lightning address (LNURL /
/// user@domain), trimmed; a bolt11 invoice or any other payment string is
/// refused. A parser failure is no address; a programmer error is thrown.
class ValidateLightningAddressUsecase {
  final PaymentRequestParser _parse;

  const ValidateLightningAddressUsecase({this._parse = PaymentRequest.parse});

  Future<Result<Destination, ExchangeFailure>> execute(String text) async =>
      switch (await _lightningAddressOf(text)) {
        final address? => Ok(DestinationAddress(BtcNetwork.lightning, address)),
        null => const Err(
          ExchangeDestinationInvalidFailure('not a lightning address'),
        ),
      };

  Future<String?> _lightningAddressOf(String text) async {
    final trimmed = text.trim();
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
