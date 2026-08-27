import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';
import 'package:bull_tor/tor.dart';

abstract interface class RecoverBullRepository {
  @useResult
  Result<EncryptedVault, RecoverBullCoreFailure> createVault({
    required String vaultKey,
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
    TorProxyEndpoint endpoint,
  );

  @useResult
  Future<Result<String, RecoverBullCoreFailure>> fetchVaultKey(
    String identifier,
    String password,
    String salt,
    TorProxyEndpoint endpoint,
  );

  Future<void> trashVaultKey(
    String identifier,
    String password,
    String salt,
    TorProxyEndpoint endpoint,
  );

  Future<void> checkConnection(TorProxyEndpoint endpoint);

  Future<Uri> fetchUrl();

  Future<void> storeUrl(Uri url);

  Future<void> allowPermission(bool isGranted);

  Future<bool> fetchPermission();
}
