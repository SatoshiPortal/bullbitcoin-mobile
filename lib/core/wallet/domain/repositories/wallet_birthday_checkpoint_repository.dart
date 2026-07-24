import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_birthday_checkpoint.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_birthday_checkpoint_failure.dart';

/// Resolves a requested birthday to the concrete block a sync backend
/// should treat as a wallet's starting point — see [WalletBirthdayCheckpoint]
/// for the anchor this produces.
///
/// An implementation talks to whatever backend can answer "what block
/// corresponds to this moment in time" (a mempool/chain-tip API — see
/// `WalletBirthdayCheckpointRepositoryImpl`); see
/// `docs/compact-block-filters-technical-design.md` §4 for why this cannot
/// be derived locally from a `DateTime` alone.
///
/// [requestedBirthday] is already the exact instant to look up — any
/// mode-dependent safety margin (see `WalletBirthdayLookupMode`) is applied
/// by the caller (`ResolveWalletBirthdayCheckpointUsecase`), not here: this
/// contract only knows how to answer "what block was at or before this
/// instant", never why that instant was chosen.
abstract interface class WalletBirthdayCheckpointRepository {
  /// Resolves [requestedBirthday] to a [WalletBirthdayCheckpoint], or a
  /// [WalletBirthdayCheckpointFailure] if it cannot be resolved right now.
  /// [isTestnet] selects both the genesis constant and the active mempool
  /// server network — this resolver is Bitcoin-only. Never throws.
  Future<Result<WalletBirthdayCheckpoint, WalletBirthdayCheckpointFailure>>
  resolve({required DateTime requestedBirthday, required bool isTestnet});
}
