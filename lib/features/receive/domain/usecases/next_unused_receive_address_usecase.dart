import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;

import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show WalletFailure, WalletStorageFailure;

import 'package:bb_mobile/features/address_view/domain/usecases/get_receive_address_usecase.dart';

/// Issues addresses through the native writer, never by deriving a local index.
class NextUnusedReceiveAddressUsecase {
  final GetReceiveAddressUsecase _receive;

  const NextUnusedReceiveAddressUsecase(this._receive);

  @useResult
  Future<Result<String, WalletFailure>> execute(
    String walletId, {
    Set<String> excludedAddresses = const {},
  }) async {
    try {
      for (var attempt = 0; attempt < 20; attempt++) {
        final address = await _receive.execute(
          walletId: walletId,
          generateNew: true,
        );
        if (!address.isUsed && !excludedAddresses.contains(address.address)) {
          return Ok(address.address);
        }
      }
      return const Err(
        WalletStorageFailure('unused address attempts exhausted'),
      );
    } on Exception {
      return const Err(WalletStorageFailure('receive address unavailable'));
    }
  }
}
