import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/descriptors.dart';

/// Public-key / descriptor derivation. Everything returned is NON-secret
/// (xpub, watch-only descriptors). The seed is referenced by [Fingerprint]; the
/// raw bytes are read internally via the secret store and never escape.
abstract interface class KeyDerivationPort {
  /// Test-only derivation sanity probe (re-derives the master fingerprint from
  /// the stored bytes). NOT on the public `Secret`/`Secrets` surface — the
  /// handle already *is* the fingerprint — and has no production caller; kept
  /// only as a KAT check in `key_derivation_native_test.dart`.
  @visibleForTesting
  @useResult
  Future<Result<Fingerprint, SecretsFailure>> masterFingerprint(
      Fingerprint fingerprint);

  @useResult
  Future<Result<Xpub, SecretsFailure>> accountXpub({
    required Fingerprint fingerprint,
    required ScriptType scriptType,
    required bool isTestnet,
    required int account,
  });

  /// Returns BOTH the external and internal (change) public descriptors — the
  /// pair the app always needs together.
  @useResult
  Future<Result<BitcoinDescriptor, SecretsFailure>> bitcoinDescriptor({
    required Fingerprint fingerprint,
    required ScriptType scriptType,
    required bool isTestnet,
  });

  @useResult
  Future<Result<LiquidDescriptor, SecretsFailure>> liquidDescriptor({
    required Fingerprint fingerprint,
    required bool isTestnet,
  });
}
