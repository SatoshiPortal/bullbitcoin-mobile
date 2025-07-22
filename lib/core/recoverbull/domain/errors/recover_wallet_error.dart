import 'package:bb_mobile/core/recoverbull/domain/entity/recoverbull_wallet.dart';

class RecoverWalletError implements Exception {
  const RecoverWalletError(this.message);

  final String message;

  @override
  String toString() {
    return 'RecoverWalletError: $message';
  }
}

class DefaultWalletExistsError extends RecoverWalletError {
  final RecoverBullWallet wallet;
  const DefaultWalletExistsError(this.wallet)
    : super('This wallet already exists.');
}

class WalletMismatchError extends RecoverWalletError {
  const WalletMismatchError()
    : super(
        'A different default wallet already exists. You can only have one default wallet.',
      );
}

class WalletAlreadyExistsError extends RecoverWalletError {
  const WalletAlreadyExistsError()
    : super('A wallet with this fingerprint already exists.');
}
