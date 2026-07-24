import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_error.freezed.dart';

@freezed
sealed class WalletError with _$WalletError {
  const factory WalletError.notFound(String walletId) = WalletNotFound;
  const factory WalletError.cannotDeleteDefaultWallet() =
      CannotDeleteDefaultWalletError;
  const factory WalletError.cannotDeleteWalletWithOngoingSwaps() =
      CannotDeleteWalletWithOngoingSwapsError;
  // Blocked, never a shutdown: normal app code must not kill an active CBF
  // session (see CbfSyncActivityPort's class doc) — the caller must retry
  // once the wallet's compact block filter sync settles on its own.
  const factory WalletError.cannotDeleteWalletWithActiveCbfSync() =
      CannotDeleteWalletWithActiveCbfSyncError;
  const factory WalletError.unexpected(String message) = UnexpectedWalletError;
  const WalletError._();
}
