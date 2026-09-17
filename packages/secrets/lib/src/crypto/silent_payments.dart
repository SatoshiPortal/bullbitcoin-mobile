import 'package:bull_sdk/bwk.dart';
import 'package:secrets/src/crypto/exceptions.dart';
import 'package:secrets/src/domain/domain.dart';

export 'package:bull_sdk/bwk.dart'
    show SpAccount, SpHeaderCheckpoint, SpNetwork;

/// Opens the bwk Silent Payments account (BIP352) of a mnemonic.
///
/// ⚠️ The one place the stored words leave this package for a library: bwk-dart builds an account from a mnemonic only, and the account it returns keeps the keys for as long as it lives. A key-based constructor (bwk-bitcoin/bwk#114) would let the package hand over derived keys instead.
abstract final class SilentPayments {
  static Future<SpAccount> open(
    MnemonicMaterial secret, {
    required String name,
    required SpNetwork network,
    required String blindbitUrl,
    required String electrumUrl,
    required String dataDir,
    required BigInt dustLimit,
    required int fetchConcurrencyFactor,
    required int matchConcurrencyFactor,
    required SpHeaderCheckpoint? headerCheckpoint,
  }) async {
    // bwk derives from the words alone, so a passphrase would silently open
    // the passphrase-less sibling's wallet.
    if (secret.hasPassphrase) {
      throw const PassphraseUnsupported('bwk derives from the words alone');
    }
    try {
      return await SpAccount.createFromMnemonicWithScanRuntime(
        name: name,
        network: network,
        mnemonic: secret.words.join(' '),
        blindbitUrl: blindbitUrl,
        electrumUrl: electrumUrl,
        dataDir: dataDir,
        dustLimit: dustLimit,
        fetchConcurrencyFactor: fetchConcurrencyFactor,
        matchConcurrencyFactor: matchConcurrencyFactor,
        headerCheckpoint: headerCheckpoint,
      );
    } catch (_) {
      // bwk's error is a string that can quote its input; only the type leaves.
      throw const SilentPaymentsOpenFailed();
    }
  }
}
