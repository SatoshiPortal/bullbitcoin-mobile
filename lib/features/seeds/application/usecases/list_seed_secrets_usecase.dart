import 'package:bb_mobile/features/seeds/application/ports/seed_secret_store_port.dart';
import 'package:bb_mobile/core/primitives/seeds/seed_secret.dart';

class ListSeedSecretsQuery {
  // final SeedSecretKind kind;

  const ListSeedSecretsQuery();
}

class ListSeedSecretsResult {
  final List<SeedSecret> secrets;

  const ListSeedSecretsResult({required this.secrets});
}

class ListSeedSecretsUseCase {
  final SeedSecretStorePort _seedSecretStore;

  ListSeedSecretsUseCase({required SeedSecretStorePort seedSecretStore})
    : _seedSecretStore = seedSecretStore;

  Future<ListSeedSecretsResult> execute(ListSeedSecretsQuery query) async {
    final secrets = await _seedSecretStore.listAll();

    return ListSeedSecretsResult(secrets: secrets);
  }
}
