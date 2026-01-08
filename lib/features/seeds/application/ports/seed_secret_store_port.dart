import 'package:bb_mobile/core/primitives/seeds/seed_secret.dart';

// Named store instead of repository since it only handles the secrets itself,
// and doesn't have any complex querying capabilities.
abstract interface class SeedSecretStorePort {
  Future<void> save({required String fingerprint, required SeedSecret secret});
  Future<SeedSecret> load(String fingerprint);
  //Future<List<String>> listSeedFingerprints();
  Future<List<SeedSecret>> listAll();
  Future<bool> exists(String fingerprint);
  Future<void> delete(String fingerprint);
}
