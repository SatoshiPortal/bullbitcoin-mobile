import 'package:bull_exchange/src/payin/payin_wallets.dart';
import 'package:bull_exchange/src/pay/domain/pay_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show WalletKey;

/// Derives a stand-in address for fee estimation without issuing it.
class GetPayPayinAddressUsecase {
  final PayinWallets _wallets;
  const GetPayPayinAddressUsecase(this._wallets);

  @useResult
  Future<Result<String, PayFailure>> execute({
    required WalletKey walletKey,
    int index = 0,
  }) async => (await _wallets.addressAt(walletKey, index)).mapErr(
    (failure) =>
        PayUnexpectedFailure('Fee address unavailable: ${failure.logCode}'),
  );
}
