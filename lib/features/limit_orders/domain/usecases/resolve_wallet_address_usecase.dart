import 'package:address_view/address_view.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';
import 'package:meta/meta.dart';

class ResolveWalletAddressUsecase {
  final AddressView _getReceiveAddress;

  const ResolveWalletAddressUsecase(this._getReceiveAddress);

  @useResult
  Future<Result<String, LimitOrdersFailure>> execute(String walletId) async {
    return (await _getReceiveAddress.receiveAddress(walletId: walletId))
        .map((address) => address.address)
        .mapErr(
          (failure) =>
              LimitOrdersUnexpectedFailure(failure.runtimeType.toString()),
        );
  }
}
