import 'package:bb_mobile/features/seeds/application/ports/seed_secret_store_port.dart';
import 'package:bb_mobile/core/primitives/seeds/seed_secret.dart';
import 'package:bb_mobile/features/seeds/application/seeds_application_errors.dart';
import 'package:bb_mobile/features/seeds/domain/seeds_domain_errors.dart';

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
    try {
      final secret = await _seedSecretStore.load(query.fingerprint);

      return GetSeedSecretResult(secret: secret);
    } on SeedsDomainError catch (e) {
      // Map domain errors to application errors
      // For now just wrap all in a generic business rule failed
      throw BusinessRuleFailed(e);
    } on SeedsApplicationError {
      rethrow;
    } catch (e) {
      throw FailedToGetSeedSecretError(query.fingerprint, e);
    }
  }
}
