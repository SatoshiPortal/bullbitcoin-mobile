import 'package:bb_mobile/core_deprecated/wallet/data/models/transaction_output_model.dart';
import 'package:synchronized/synchronized.dart';

class FrozenWalletUtxoDatasource {
  late Lock _lock;

  FrozenWalletUtxoDatasource() {
    _lock = Lock();
  }

  // Run a custom sequence with a lock to ensure atomicity
  Future<T> withLock<T>(Future<T> Function() action) {
    return _lock.synchronized(() async => await action());
  }

  Future<void> freezeWalletUtxo({
    required String walletId,
    required TransactionOutputModel utxo,
  }) async {
    await _lock.synchronized(() {});
  }

  Future<List<TransactionOutputModel>> getFrozenWalletUtxos({
    required String walletId,
  }) async {
    final frozenUtxos = await _lock.synchronized(() {
      return <TransactionOutputModel>[];
    });

    return frozenUtxos;
  }

  Future<void> unfreezeWalletUtxo({
    required String walletId,
    required TransactionOutputModel utxo,
  }) async {
    await _lock.synchronized(() {});
  }
}
