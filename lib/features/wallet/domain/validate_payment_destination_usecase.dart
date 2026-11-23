import 'package:primitives/primitives.dart' show BitcoinNetwork;
import 'package:satoshifier/payment_request.dart';

import 'payment_destination.dart';

/// Adapts the legacy parser to the destination capabilities of a form.
final class ValidatePaymentDestinationUsecase {
  final Future<PaymentRequest> Function(String) _parse;

  const ValidatePaymentDestinationUsecase({this._parse = PaymentRequest.parse});

  Future<PaymentDestination?> execute(
    String raw, {
    required Set<PaymentDestinationType> acceptedTypes,
    bool allowLnurl = true,
  }) async {
    if (raw.trim().isEmpty) return null;
    try {
      final request = await _parse(raw);
      final destination = switch (request) {
        BitcoinPaymentRequest(:final address) => PaymentDestination(
          raw: raw,
          address: address,
          type: PaymentDestinationType.bitcoin,
        ),
        LiquidPaymentRequest(:final address) => PaymentDestination(
          raw: raw,
          address: address,
          type: PaymentDestinationType.liquid,
        ),
        LnAddressPaymentRequest(:final address) => PaymentDestination(
          raw: raw,
          address: address,
          type: PaymentDestinationType.lightningAddress,
          isLnurl: !address.contains('@'),
        ),
        Bip21PaymentRequest(:final address, :final network, :final amountSat) =>
          PaymentDestination(
            raw: raw,
            address: address,
            type: network is BitcoinNetwork
                ? PaymentDestinationType.bitcoin
                : PaymentDestinationType.liquid,
            amountSat: amountSat,
          ),
        _ => null,
      };
      if (destination == null ||
          !acceptedTypes.contains(destination.type) ||
          (!allowLnurl && destination.isLnurl)) {
        return null;
      }
      return destination;
    } on Error {
      rethrow;
    } catch (_) {
      return null;
    }
  }
}
