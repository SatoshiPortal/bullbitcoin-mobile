import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';
import 'package:primitives/primitives.dart';

class SyncSpForWalletUsecase {
  final SpFacade _sp;

  const SyncSpForWalletUsecase(this._sp);

  Future<Result<void, WalletFailure>> execute() async {
    return switch (await _sp.syncWallet()) {
      Ok() => const Ok(null),
      Err() => const Err(WalletSyncFailure('Silent Payments sync failed')),
    };
  }
}
