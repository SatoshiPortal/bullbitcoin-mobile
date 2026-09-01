import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

/// Reads the balance sitting behind a passphrase wallet's public descriptor,
/// so a locked card can show one without mounting the wallet.
///
/// The implementation owns the BDK and Electrum details and uses the user's
/// already configured Electrum path — this capability introduces no second
/// service, and it never logs the descriptor it was given.
abstract interface class PassphraseWalletScanner {
  /// Throws [PassphraseWalletScanException] when the scan cannot complete.
  Future<BigInt> scan({
    required String combinedPublicDescriptor,
    required Network network,
  });
}

/// A scan that did not complete.
///
/// Carries no descriptor: it identifies the wallet, and this exception ends up
/// in logs and error reports.
final class PassphraseWalletScanException implements Exception {
  const PassphraseWalletScanException();

  @override
  String toString() => 'PassphraseWalletScanException';
}
