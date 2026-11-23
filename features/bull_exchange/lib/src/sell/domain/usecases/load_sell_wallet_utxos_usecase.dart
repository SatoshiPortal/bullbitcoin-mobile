import 'package:bull_exchange/src/payin/payin_wallets.dart';
import 'package:bull_exchange/src/sell/domain/sell_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

class LoadSellWalletUtxosUsecase {
  final PayinWallets _wallets;
  const LoadSellWalletUtxosUsecase(this._wallets);

  @useResult
  Future<Result<List<Coin>, SellFailure>> execute({
    required WalletKey walletKey,
  }) async => (await _wallets.coins(walletKey)).mapErr(
    (failure) =>
        SellUnexpectedFailure('Coin control unavailable: ${failure.logCode}'),
  );
}
