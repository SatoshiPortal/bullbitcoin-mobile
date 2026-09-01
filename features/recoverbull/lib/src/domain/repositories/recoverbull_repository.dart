import 'package:bull_recoverbull/src/domain/entities/decrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';
import '../entities/key_server_attempts.dart';
import '../recoverbull_tor_route.dart';

abstract interface class RecoverBullRepository {
  @useResult
  Future<
    Result<({EncryptedVault vault, String vaultKey}), RecoverBullCoreFailure>
  >
  createVault({
    required String rootXprv,
    required String plaintext,
    required String derivationPath,
  });

  @useResult
  Result<DecryptedVault, RecoverBullCoreFailure> restoreVault({
    required EncryptedVault vault,
    required String vaultKey,
  });

  @useResult
  Future<Result<Null, RecoverBullCoreFailure>> storeVaultKey(
    String identifier,
    String password,
    String salt,
    String vaultKey,
    RecoverBullTorRoute route,
  );

  @useResult
  Future<Result<String, RecoverBullCoreFailure>> fetchVaultKey(
    String identifier,
    String password,
    String salt,
    RecoverBullTorRoute route,
  );

  @useResult
  Future<Result<VaultKeyFetchResult, RecoverBullCoreFailure>>
  fetchVaultKeyWithStatus(
    String identifier,
    String password,
    String salt,
    RecoverBullTorRoute route,
  );

  @useResult
  Future<Result<VaultKeyFetchResult, RecoverBullCoreFailure>>
  trashVaultKeyWithStatus(
    String identifier,
    String password,
    String salt,
    RecoverBullTorRoute route,
  );

  Future<void> trashVaultKey(
    String identifier,
    String password,
    String salt,
    RecoverBullTorRoute route,
  );

  Future<void> checkConnection(RecoverBullTorRoute route);

  Future<Uri> fetchUrl();

  Future<void> storeUrl(Uri url);

  Future<void> allowPermission(bool isGranted);

  Future<bool> fetchPermission();
}
