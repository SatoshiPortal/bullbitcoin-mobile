import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_error.freezed.dart';

@freezed
sealed class WalletError with _$WalletError {
  const factory WalletError.notFound(String walletId) = WalletNotFound;
  const factory WalletError.cannotDeleteDefaultWallet() =
      CannotDeleteDefaultWalletError;
  const factory WalletError.cannotDeleteWalletWithOngoingSwaps() =
      CannotDeleteWalletWithOngoingSwapsError;
  const factory WalletError.unexpected(String message) = UnexpectedWalletError;
  const factory WalletError.noDefaultWalletFound() = NoDefaultWalletFoundError;
  const WalletError._();

  @override
  String toString() {
    return when(
      notFound: (walletId) => 'Wallet not found: $walletId',
      cannotDeleteDefaultWallet: () => 'Cannot delete the default wallet.',
      cannotDeleteWalletWithOngoingSwaps:
          () => 'Cannot delete wallet with ongoing swaps.',
      unexpected: (message) => 'Unexpected wallet error: $message',
      noDefaultWalletFound:
          () => 'No default wallet found. Please create or restore a wallet.',
    );
  }
}
