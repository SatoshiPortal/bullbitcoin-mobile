import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;

import 'package:address_view/address_view.dart';

import '../receive_failure.dart';

/// Issues addresses through the native writer, never by deriving a local index.
class NextUnusedReceiveAddressUsecase {
  final AddressView _receive;

  const NextUnusedReceiveAddressUsecase(this._receive);

  @useResult
  Future<Result<String, ReceiveFailure>> execute(
    String walletId, {
    Set<String> excludedAddresses = const {},
  }) async {
    for (var attempt = 0; attempt < 20; attempt++) {
      switch (await _receive.receiveAddress(
        walletId: walletId,
        advance: true,
      )) {
        case Err():
          return const Err(
            ReceiveAddressUnavailableFailure('receive address unavailable'),
          );
        case Ok(value: final address):
          if (!address.isUsed && !excludedAddresses.contains(address.address)) {
            return Ok(address.address);
          }
      }
    }
    return const Err(
      ReceiveAddressUnavailableFailure('unused address attempts exhausted'),
    );
  }
}
