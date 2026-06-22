import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/descriptors.dart';

/// Public-key / descriptor derivation. Everything returned is NON-secret
/// (xpub, watch-only descriptors). The seed is referenced by [Fingerprint]; the
/// raw bytes are read internally via the secret store and never escape.
abstract interface class KeyDerivationPort {
  @useResult
  Future<Result<Fingerprint, SecretsFailure>> masterFingerprint(
      Fingerprint seed);

  @useResult
  Future<Result<Xpub, SecretsFailure>> accountXpub({
    required Fingerprint seed,
    required ScriptType scriptType,
    required bool isTestnet,
    required int account,
  });

  /// Returns BOTH the external and internal (change) public descriptors — the
  /// pair the app always needs together.
  @useResult
  Future<Result<BitcoinDescriptor, SecretsFailure>> bitcoinDescriptor({
    required Fingerprint seed,
    required ScriptType scriptType,
    required bool isTestnet,
  });

  @useResult
  Future<Result<LiquidDescriptor, SecretsFailure>> liquidDescriptor({
    required Fingerprint seed,
    required bool isTestnet,
  });
}
