import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_sync_failure.dart';

/// Records a just-broadcast, wallet-owned outgoing Bitcoin transaction into
/// the wallet's own local BDK state as unconfirmed, so its balance and
/// transaction history reflect the spend immediately rather than waiting
/// for the next sync round to observe it.
///
/// A no-op [Ok] is returned for a wallet that either isn't a Bitcoin wallet
/// or is on the [BitcoinSyncBackend.electrum] backend: an Electrum wallet
/// already learns about its own broadcast the next time it syncs over the
/// Electrum protocol (which can see mempool transactions directly). Only a
/// [BitcoinSyncBackend.compactBlockFilters] wallet needs this local nudge,
/// because compact block filters (BIP157/158) alone cannot observe an
/// unconfirmed mempool transaction — a CBF light client only learns about a
/// transaction once it is mined and matches a filter.
///
/// A missing wallet is a typed [Err], not a no-op: unlike "wrong backend"
/// or "not Bitcoin" (legitimate, expected no-ops), a caller passing an
/// unknown wallet id is either a bug or a race with wallet deletion, and
/// that distinction is worth preserving in the return value even though
/// every current caller of this repository treats any [Err] as best-effort
/// and swallows it after logging (see `RecordUnconfirmedBitcoinTransactionUsecase`
/// callers) — a local recording failure must never turn an already
/// successful network broadcast into a failure or a rebroadcast risk.
///
/// Note on RBF/replacement: a replacement transaction is recorded through
/// this exact same call. `Wallet.applyUnconfirmedTxs` files it as a newer
/// unconfirmed transaction in the wallet's local tx graph; it does not, and
/// this repository must not, call `Wallet.applyEvictedTxs` on the
/// superseded transaction. Whether a peer actually dropped the superseded
/// transaction from its mempool cannot be known without further mempool
/// observation, which a CBF light client does not perform — reconciling
/// the superseded transaction (confirmed, or replaced) is left entirely to
/// the wallet's regular CBF sync applying a freshly scanned `bdk.Update`.
/// This repository never manually marks any output trusted or spendable —
/// that stays whatever `Wallet.applyUnconfirmedTxs`'s own canonicalization
/// decides.
abstract interface class UnconfirmedBitcoinTransactionRepository {
  /// [transaction] is a signed PSBT when [isPsbt], otherwise a raw
  /// hex-encoded transaction — mirroring the shape `BroadcastBitcoinTransactionUsecase`
  /// already accepts, so callers can forward the exact value they just
  /// broadcast.
  Future<Result<void, WalletSyncFailure>> record({
    required String walletId,
    required String transaction,
    required bool isPsbt,
  });
}
