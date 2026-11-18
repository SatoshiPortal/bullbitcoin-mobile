import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/features/wallet/domain/payment_destination.dart';
import 'package:primitives/primitives.dart'
    show BitcoinNetwork, LiquidNetwork, Ok;
import 'package:sync/sync.dart' show parseBitcoinAddress, liquidAddressNetwork;

/// Adapts the legacy parser to the destination capabilities of a form.
final class ValidatePaymentDestinationUsecase {
  final Future<PaymentRequest> Function(String) _parse;

  const ValidatePaymentDestinationUsecase({this._parse = PaymentRequest.parse});

  Future<PaymentDestination?> execute(
    String raw, {
    required Set<PaymentDestinationType> acceptedTypes,
    bool allowLnurl = true,
    bool allowRegtest = true,
  }) async {
    if (raw.trim().isEmpty) return null;
    try {
      final destination = await _destination(raw, allowRegtest: allowRegtest);
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

  Future<PaymentDestination?> _destination(
    String raw, {
    required bool allowRegtest,
  }) async {
    final address = raw.trim();
    final prefix = address.toLowerCase();
    final isRawAddress = RegExp(r'^[a-zA-Z0-9]+$').hasMatch(address);
    if (isRawAddress && prefix.startsWith('bcrt1')) {
      if (!allowRegtest) return null;
      return switch (parseBitcoinAddress(address, BitcoinNetwork.regtest)) {
        Ok(:final value) => PaymentDestination(
          raw: raw,
          address: value,
          type: PaymentDestinationType.bitcoin,
        ),
        _ => null,
      };
    }
    if (isRawAddress &&
        (prefix.startsWith('ert1') || prefix.startsWith('el1'))) {
      if (!allowRegtest) return null;
      return switch (await liquidAddressNetwork(address)) {
        Ok(value: LiquidNetwork.regtest) => PaymentDestination(
          raw: raw,
          address: address,
          type: PaymentDestinationType.liquid,
        ),
        _ => null,
      };
    }
    final request = await _parse(raw);
    return switch (request) {
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
          type: network.isBitcoin
              ? PaymentDestinationType.bitcoin
              : PaymentDestinationType.liquid,
          amountSat: amountSat,
        ),
      _ => null,
    };
  }
}
