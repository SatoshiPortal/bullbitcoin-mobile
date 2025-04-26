import 'package:bb_mobile/core/wallet/data/models/transaction_output_model.dart';
import 'package:synchronized/synchronized.dart';

class FrozenUtxoDatasource {
  late Lock _lock;

  FrozenUtxoDatasource() {
    _lock = Lock();
  }

  // Run a custom sequence with a lock to ensure atomicity
  Future<T> withLock<T>(Future<T> Function() action) {
    return _lock.synchronized(() async => await action());
  }

  Future<void> freezeUtxo({
    required String walletId,
    required TransactionOutputModel utxo,
  }) async {
    await _lock.synchronized(() {});
  }

  Future<List<TransactionOutputModel>> getFrozenUtxos(
      {required String walletId}) async {
    final frozenUtxos = await _lock.synchronized(() {
      return <TransactionOutputModel>[];
    });

    return frozenUtxos;
  }

  Future<void> unfreezeUtxo({
    required String walletId,
    required TransactionOutputModel utxo,
  }) async {
    await _lock.synchronized(() {});
  }
}
