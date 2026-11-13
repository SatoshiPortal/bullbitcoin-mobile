import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show VaultKey;

import '../entities/attempt_observation.dart';
import '../entities/encrypted_vault.dart';
import '../entities/vault_key_fetch.dart';
import '../recoverbull_failure.dart';

/// One already-selected server and one flow-owned transport. A server change
/// requires a new session; in-flight operations cannot switch destinations.
abstract interface class KeyServerRepository {
  @useResult
  Future<Result<void, RecoverBullFailure>> probe();

  @useResult
  Future<Result<void, RecoverBullFailure>> store(
    EncryptedVault vault,
    String password,
    VaultKey key,
  );

  @useResult
  Future<Result<VaultKeyFetch, RecoverBullFailure>> fetch(
    EncryptedVault vault,
    String password,
  );

  @useResult
  Future<Result<VaultKeyFetch, RecoverBullFailure>> trash(
    EncryptedVault vault,
    String password,
  );

  @useResult
  Future<Result<AttemptSnapshot, RecoverBullFailure>> attempts(
    Set<String> digests,
  );

  Future<void> close();
}
