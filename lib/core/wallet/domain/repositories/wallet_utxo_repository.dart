import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';

abstract interface class WalletUtxoRepository {
  Future<List<WalletUtxo>> getWalletUtxos({
    required String walletId,
  });

  /// Freezes the given outpoints for a wallet (writes `origin = 'user'` rows).
  Future<void> freezeUtxos({
    required String walletId,
    required List<Outpoint> outpoints,
  });

  /// Unfreezes the given outpoints. Only ever deletes `origin = 'user'` rows —
  /// a user can never unfreeze a system/payjoin lock.
  Future<void> unfreezeUtxos({
    required String walletId,
    required List<Outpoint> outpoints,
  });

  /// Returns the frozen outpoints for a wallet. `origins == null` returns all
  /// rows (the send-exclusion read); pass `{'user'}` for the user-frozen set
  /// the Coins UI shows/toggles.
  Future<List<Outpoint>> getFrozenOutpoints({
    required String walletId,
    Set<String>? origins,
  });
}
