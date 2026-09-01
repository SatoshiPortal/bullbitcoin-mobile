import 'package:bb_mobile/features/passphrase_wallet/domain/entities/passphrase_wallet.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/passphrase_wallet_failure.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/passphrase_wallet_scanner.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;

/// Reads one locked wallet's balance from its public descriptor (spec 20.7).
///
/// Scanning is driven from the Passphrase page and nowhere else: the page Cubit
/// runs these one card at a time on entry, and there is no background scan
/// (spec 6.4).
final class ScanPassphraseWalletBalanceUsecase {
  final PassphraseWalletScanner _scanner;

  const ScanPassphraseWalletBalanceUsecase(this._scanner);

  Future<Result<PassphraseWalletBalance, PassphraseWalletFailure>> execute(
    PassphraseWalletRecord wallet,
  ) async {
    try {
      final satoshis = await _scanner.scan(
        combinedPublicDescriptor: wallet.descriptor,
        network: wallet.network,
      );
      return Ok(PassphraseWalletBalance(satoshis: satoshis));
    } on Exception {
      return const Err(PassphraseWalletSyncFailure());
    }
  }
}
