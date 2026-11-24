import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart';

class ReadSwapCoinsUsecase {
  final WalletNativeRuntime _sync;

  const ReadSwapCoinsUsecase(this._sync);

  Future<Result<CoinList, SyncFailure>> execute(WalletKey wallet) async =>
      switch (await _sync.loadWallet(wallet)) {
        Ok(:final value) => value.coins.now.latest,
        Err(:final failure) => Err(failure),
      };
}
