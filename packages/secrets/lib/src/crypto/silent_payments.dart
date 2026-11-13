import 'dart:typed_data';

import 'package:bull_sdk/bwk.dart';
import 'package:secrets/src/crypto/exceptions.dart';
import 'package:secrets/src/domain/domain.dart';

export 'package:bull_sdk/bwk.dart'
    show SpAccount, SpHeaderCheckpoint, SpNetwork;

/// Opens the bwk Silent Payments account (BIP352) of a mnemonic.
///
/// The BIP39 seed crosses into bwk inside this package. The returned native account retains signing capability until disposed; copies inside Dart and the bridge cannot all be guaranteed erased.
abstract final class SilentPayments {
  /// Derives the public BIP352 address without opening an account or files.
  static Future<String> address(
    Mnemonic secret, {
    required SpNetwork network,
  }) async {
    final seed = Uint8List.fromList(secret.seedBytes);
    try {
      return await deriveSpAddressFromSeed(seed: seed, network: network);
    } catch (_) {
      throw const SilentPaymentsAddressFailed();
    } finally {
      seed.fillRange(0, seed.length, 0);
    }
  }

  static Future<SpAccount> open(
    Mnemonic secret, {
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
    final seed = Uint8List.fromList(secret.seedBytes);
    try {
      return await SpAccount.createFromSeedWithScanRuntime(
        name: name,
        network: network,
        seed: seed,
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
    } finally {
      seed.fillRange(0, seed.length, 0);
    }
  }
}
