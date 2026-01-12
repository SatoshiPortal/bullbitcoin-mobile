import 'package:bb_mobile/core/primitives/secrets/secret.dart';

// Named store instead of repository since it only handles the secrets themselves,
// and doesn't have any complex querying capabilities.
abstract interface class SecretStorePort {
  Future<void> save({required String fingerprint, required Secret secret});
  Future<Secret> load(String fingerprint);
  //Future<List<String>> listSeedFingerprints();
  Future<List<Secret>> loadAll();
  Future<bool> exists(String fingerprint);
  Future<void> delete(String fingerprint);
}
