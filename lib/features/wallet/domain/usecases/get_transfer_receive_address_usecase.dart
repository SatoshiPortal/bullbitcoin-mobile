import 'package:primitives/primitives.dart';

import '../wallet_discovery_failure.dart';

import 'package:bb_mobile/features/address_view/domain/usecases/get_receive_address_usecase.dart';

/// Maps the legacy address reader's exceptions at the public wallet boundary.
final class GetTransferReceiveAddressUsecase {
  final GetReceiveAddressUsecase _receive;
  const GetTransferReceiveAddressUsecase(this._receive);

  Future<Result<String, WalletDiscoveryFailure>> execute(
    String walletId,
  ) async {
    try {
      final address = await _receive.execute(walletId: walletId);
      return Ok(address.address);
    } on Exception {
      return const Err(WalletDiscoveryUnavailableFailure());
    }
  }
}
