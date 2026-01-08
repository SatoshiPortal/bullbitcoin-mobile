import 'package:bb_mobile/features/seeds/application/ports/seed_secret_store_port.dart';
import 'package:bb_mobile/core/primitives/seeds/seed_secret.dart';

class GetSeedSecretQuery {
  final String fingerprint;

  const GetSeedSecretQuery({required this.fingerprint});
}

class GetSeedSecretResult {
  final SeedSecret secret;

  const GetSeedSecretResult({required this.secret});
}

class GetSeedSecretUseCase {
  final SeedSecretStorePort _seedSecretStore;

  GetSeedSecretUseCase({required SeedSecretStorePort seedSecretStore})
    : _seedSecretStore = seedSecretStore;

  Future<GetSeedSecretResult> execute(GetSeedSecretQuery query) async {
    final secret = await _seedSecretStore.load(query.fingerprint);

    return GetSeedSecretResult(secret: secret);
  }
}
