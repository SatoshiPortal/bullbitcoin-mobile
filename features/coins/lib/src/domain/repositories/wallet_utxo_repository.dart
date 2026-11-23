import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Outpoint, Result;
import 'package:coins/src/domain/coins_failure.dart';
import 'package:coins/src/domain/wallet_utxo.dart';

abstract interface class WalletUtxoRepository {
  @useResult
  Future<Result<List<WalletUtxo>, CoinsFailure>> getWalletUtxos({
    required String walletId,
  });

  /// Freezes the given outpoints, attributed to [walletId] (the wallet origin).
  @useResult
  Future<Result<void, CoinsFailure>> freezeUtxos({
    required String walletId,
    required List<Outpoint> outpoints,
  });

  /// Unfreezes the given outpoints. Matched by outpoint (like exclusion), so a
  /// coin shown as frozen is always unfreezable regardless of which `walletId`
  /// its row carries.
  @useResult
  Future<Result<void, CoinsFailure>> unfreezeUtxos({
    required String walletId,
    required List<Outpoint> outpoints,
  });

  /// Returns every frozen outpoint across all wallets.
  ///
  /// Freeze is matched by outpoint, not by wallet: an outpoint is globally
  /// unique, so a coin is frozen iff any wallet froze it. `getWalletUtxos` and
  /// the send path overlay this set onto BDK's real coins — a frozen row that
  /// no wallet currently owns is inert (nothing to attach to). The stored
  /// `walletId` (the wallet origin) is kept only for BIP329 export attribution,
  /// never for exclusion.
  @useResult
  Future<Result<List<Outpoint>, CoinsFailure>> getAllFrozenOutpoints();
}
