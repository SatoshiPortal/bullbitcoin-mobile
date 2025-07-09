import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_error.freezed.dart';

@freezed
sealed class WalletError with _$WalletError {
  const factory WalletError.walletNotFound(String walletId) = WalletNotFound;
  const factory WalletError.unexpected(String message) = UnexpectedWalletError;
  const WalletError._();
}
