import 'package:primitives/primitives.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:address_view/address_view.dart';
import 'package:receive/receive.dart';
import 'package:meta/meta.dart';

class PrepareReceiveAddressUsecase {
  final AddressView _addresses;

  const PrepareReceiveAddressUsecase(this._addresses);

  @useResult
  Future<Result<WalletAddress, ReceiveFailure>> execute({
    required String walletId,
    bool generateNew = false,
  }) async {
    final result = await _addresses.receiveAddress(
      walletId: walletId,
      advance: generateNew,
    );
    return result.mapErr((failure) {
      if (failure is! AddressViewWriterBusyFailure) {
        log.warning('Receive address failed reason=unavailable');
      }
      return const ReceiveAddressUnavailableFailure('unavailable');
    });
  }
}
