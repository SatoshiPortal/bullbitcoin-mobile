import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_error.freezed.dart';

@freezed
sealed class WalletError with _$WalletError {
  const factory WalletError.walletNotFound() = WalletNotFoundError;
  const factory WalletError.cannotDeleteDefaultWallet() =
      CannotDeleteDefaultWalletError;
  const factory WalletError.cannotDeleteWalletWithOngoingSwaps() =
      CannotDeleteWalletWithOngoingSwapsError;
  const factory WalletError.unexpected(String message) = UnexpectedWalletError;
}
