import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';

abstract interface class WalletUtxoRepository {
  Future<List<WalletUtxo>> getWalletUtxos({
    required String walletId,
  });

  /// Freezes the given outpoints, attributed to [walletId] (the wallet origin).
  Future<void> freezeUtxos({
    required String walletId,
    required List<Outpoint> outpoints,
  });

  /// Unfreezes the given outpoints. Matched by outpoint (like exclusion), so a
  /// coin shown as frozen is always unfreezable regardless of which `walletId`
  /// its row carries.
  Future<void> unfreezeUtxos({
    required String walletId,
    required List<Outpoint> outpoints,
  });

  /// Returns every frozen outpoint across all wallets.
  ///
  /// Freeze is matched by outpoint, not by wallet: an outpoint is globally
  /// unique, so a coin is frozen iff any wallet froze it. `getWalletUtxos` and
  /// the send path overlay this set onto BDK's real coins — a frozen row that
  /// no wallet currently owns is inert (nothing to attach to). The stored
  /// `walletId` (the wallet origin) is kept only for BIP329 export attribution
  /// and wallet-deletion cleanup, never for exclusion.
  Future<List<Outpoint>> getAllFrozenOutpoints();
}
