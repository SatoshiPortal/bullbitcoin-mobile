import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart';
import 'package:meta/meta.dart';

import '../transaction_failure.dart';

class GetTransactionWalletUsecase {
  final WalletInventory _inventory;
  final Future<Result<void, SyncFailure>> Function(WalletKey) _synchronize;

  const GetTransactionWalletUsecase(this._inventory, this._synchronize);

  @useResult
  Future<Result<WalletRegistration?, TransactionFailure>> execute(
    String walletId, {
    bool sync = false,
  }) async {
    final wallet = await _inventory.readWallet(walletId);
    switch (wallet) {
      case Err(failure: WalletRegistrationNotFoundFailure()):
        return const Ok(null);
      case Err(:final failure):
        return Err(
          TransactionUnexpectedFailure(
            'Wallet inventory: ${failure.runtimeType}',
          ),
        );
      case Ok(:final value):
        if (sync) {
          final synced = await _synchronize(
            WalletKey(id: value.id, network: value.network),
          );
          if (synced case Err(:final failure)) {
            return Err(
              TransactionUnexpectedFailure('Wallet sync: ${failure.logCode}'),
            );
          }
        }
        return Ok(value);
    }
  }
}
