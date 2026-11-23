import 'package:bull_exchange/src/payin/payin_wallets.dart';
import 'package:bull_exchange/src/pay/domain/pay_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

class LoadPayWalletUtxosUsecase {
  final PayinWallets _wallets;
  const LoadPayWalletUtxosUsecase(this._wallets);

  @useResult
  Future<Result<List<Coin>, PayFailure>> execute({
    required WalletKey walletKey,
  }) async => (await _wallets.coins(walletKey)).mapErr(
    (failure) =>
        PayUnexpectedFailure('Coin control unavailable: ${failure.logCode}'),
  );
}
