import '../entities/decrypted_vault.dart';
import '../entities/encrypted_vault.dart';
import '../recoverbull_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';
import '../entities/key_server_attempts.dart';
import '../recoverbull_tor_route.dart';
import '../entities/recoverbull_network.dart';
import '../entities/recoverbull_status.dart';

abstract interface class RecoverBullRepository {
  @useResult
  Future<Result<({EncryptedVault vault, String vaultKey}), RecoverBullFailure>>
  createVault({
    required String rootXprv,
    required String plaintext,
    required String derivationPath,
  });

  @useResult
  Result<DecryptedVault, RecoverBullFailure> restoreVault({
    required EncryptedVault vault,
    required String vaultKey,
  });

  @useResult
  Future<Result<Null, RecoverBullFailure>> storeVaultKey(
    String identifier,
    String password,
    String salt,
    String vaultKey,
    RecoverBullTorRoute route,
  );

  @useResult
  Future<Result<String, RecoverBullFailure>> fetchVaultKey(
    String identifier,
    String password,
    String salt,
    RecoverBullTorRoute route,
  );

  @useResult
  Future<Result<VaultKeyFetchResult, RecoverBullFailure>>
  fetchVaultKeyWithStatus(
    String identifier,
    String password,
    String salt,
    RecoverBullTorRoute route,
  );

  @useResult
  Future<Result<VaultKeyFetchResult, RecoverBullFailure>>
  trashVaultKeyWithStatus(
    String identifier,
    String password,
    String salt,
    RecoverBullTorRoute route,
  );

  @useResult
  Future<Result<Null, RecoverBullFailure>> checkConnection(
    RecoverBullTorRoute route,
  );

  Future<Uri> fetchUrl();

  Future<void> storeUrl(Uri url);

  Future<void> allowPermission(bool isGranted);

  Future<bool> fetchPermission();

  /// Never throws: an unreadable store is reported as an unknown status.
  Future<RecoverBullStatus> fetchBackupStatus(RecoverBullNetwork network);

  Future<void> markBackupStored(RecoverBullNetwork network);

  Future<void> markBackupVerified(RecoverBullNetwork network);
}
