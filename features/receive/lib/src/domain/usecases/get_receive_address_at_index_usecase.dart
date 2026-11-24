import 'package:primitives/primitives.dart';
import 'package:address_view/address_view.dart';
import 'package:receive/receive.dart';
import 'package:meta/meta.dart';

/// Reads the indexed address through Address View.
class GetReceiveAddressAtIndexUsecase {
  final AddressView _addresses;

  const GetReceiveAddressAtIndexUsecase(this._addresses);

  @useResult
  Future<Result<WalletAddress, ReceiveFailure>> execute({
    required String walletId,
    required int index,
  }) async => (await _addresses.at(walletId: walletId, index: index)).mapErr(
    (failure) =>
        ReceiveAddressUnavailableFailure(failure.runtimeType.toString()),
  );
}
