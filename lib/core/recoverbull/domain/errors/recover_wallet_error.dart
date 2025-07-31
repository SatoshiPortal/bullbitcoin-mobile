import 'package:freezed_annotation/freezed_annotation.dart';

part 'recover_wallet_error.freezed.dart';

@freezed
sealed class RecoverWalletError with _$RecoverWalletError implements Exception {
  const factory RecoverWalletError.defaultWalletExists() =
      DefaultWalletExistsError;

  const factory RecoverWalletError.walletMismatch() = WalletMismatchError;

  @override
  String toString() {
    return when(
      defaultWalletExists:
          () => 'RecoverWalletError: This wallet already exists.',
      walletMismatch:
          () => 'RecoverWalletError: Backup does not match the default wallet.',
    );
  }
}
