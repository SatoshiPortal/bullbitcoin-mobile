import 'package:address_view/address_view.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Derives one of our own addresses, used as the stand-in a payin is priced
/// against before the order has one.
class GetPayPayinAddressUsecase {
  final AddressView _addresses;

  const GetPayPayinAddressUsecase({required this._addresses});

  @useResult
  Future<Result<String, PayFailure>> execute({
    required String walletId,
    int index = 0,
  }) async => (await _addresses.at(walletId: walletId, index: index))
      .map((address) => address.address)
      .mapErr(
        (failure) => PayUnexpectedFailure(failure.runtimeType.toString()),
      );
}
