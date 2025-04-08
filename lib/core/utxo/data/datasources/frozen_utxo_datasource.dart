import 'package:bb_mobile/core/utxo/data/models/utxo_model.dart';
import 'package:synchronized/synchronized.dart';

abstract class FrozenUtxoDatasource {
  /// Freezes a UTXO for a given wallet ID.
  Future<void> freezeUtxo({
    required String walletId,
    required UtxoModel utxo,
  });

  /// Fetches the frozen UTXO set for a given wallet ID.
  ///
  /// Returns a list of UTXOs associated with the wallet ID.
  Future<List<UtxoModel>> getFrozenUtxos({
    required String walletId,
  });

  /// Unfreezes a UTXO for a given wallet ID.
  Future<void> unfreezeUtxo({
    required String walletId,
    required UtxoModel utxo,
  });
}

class LocalStorageFrozenUtxoDatasource implements FrozenUtxoDatasource {
  late Lock _lock;

  LocalStorageFrozenUtxoDatasource() {
    _lock = Lock();
  }

  @override
  Future<void> freezeUtxo({
    required String walletId,
    required UtxoModel utxo,
  }) async {
    await _lock.synchronized(() {});
  }

  @override
  Future<List<UtxoModel>> getFrozenUtxos({required String walletId}) async {
    final frozenUtxos = await _lock.synchronized(() {
      return <UtxoModel>[];
    });

    return frozenUtxos;
  }

  @override
  Future<void> unfreezeUtxo({
    required String walletId,
    required UtxoModel utxo,
  }) async {
    await _lock.synchronized(() {});
  }
}
