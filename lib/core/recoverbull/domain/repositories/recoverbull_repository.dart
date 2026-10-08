import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';
import 'package:bull_tor/tor.dart';

abstract interface class RecoverBullRepository {
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
