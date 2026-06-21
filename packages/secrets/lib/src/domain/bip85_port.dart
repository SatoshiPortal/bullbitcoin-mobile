import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'secrets_failure.dart';
import 'value_objects/ark_secret.dart';
import 'value_objects/backup.dart';
import 'value_objects/bip85_types.dart';
import 'value_objects/mnemonic_length.dart';

/// BIP85 child-secret derivation. Child mnemonics/hex are returned in SEALED
/// display payloads or as a [BackupKey]/[ArkSecret] — the raw child words/bytes
/// never escape as a plain getter.
abstract interface class Bip85Port {
  @useResult
  Future<Result<Bip85Derivation, SecretsFailure>> deriveChildMnemonic({
    required Fingerprint masterSeed,
    required MnemonicLength length,
    required int index,
  });

  @useResult
  Future<Result<Bip85Derivation, SecretsFailure>> deriveBip39Child({
    required Fingerprint masterSeed,
    required Bip85Application app,
    required int index,
    required MnemonicLength length,
  });

  @useResult
  Future<Result<Bip85HexResult, SecretsFailure>> deriveHex({
    required Fingerprint masterSeed,
    required int numBytes,
    required int index,
  });

  @useResult
  Future<Result<BackupKey, SecretsFailure>> deriveRecoverbullKey({
    required Fingerprint masterSeed,
    required Bip85Path path,
  });

  @useResult
  Future<Result<ArkSecret, SecretsFailure>> deriveArkSecret({
    required Fingerprint masterSeed,
  });
}
