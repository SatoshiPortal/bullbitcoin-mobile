import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/psbt.dart';
import 'package:secrets/src/domain/value_objects/signing_intent.dart';

/// Signs PSBT/PSET. The seed is read internally; only the SIGNED transaction
/// comes back. Both methods MUST validate [intent] against the decoded
/// transaction BEFORE signing and refuse on mismatch — BDK/LWK sign blindly
/// (issue #1703). Bitcoin uses a throwaway in-memory wallet; Liquid uses an
/// ephemeral temp dbpath (LWK has no in-memory mode), deleted after signing.
abstract interface class SignerPort {
  @useResult
  Future<Result<SignedPsbt, SecretsFailure>> signBitcoinPsbt({
    required Fingerprint seed,
    required Psbt psbt,
    required SigningIntent intent,
    required ScriptType scriptType,
    required bool isTestnet,
  });

  @useResult
  Future<Result<SignedPsbt, SecretsFailure>> signLiquidPset({
    required Fingerprint seed,
    required Psbt pset,
    required SigningIntent intent,
    required bool isTestnet,
  });
}
