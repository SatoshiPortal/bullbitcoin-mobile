import 'package:bb_mobile/features/secrets/domain/entities/secret_entity.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';

// Named store instead of repository since it only handles the secrets themselves,
// and doesn't have any complex querying capabilities.
abstract interface class SecretStorePort {
  Future<void> save(Secret secret);
  Future<Secret> load(Fingerprint fingerprint);
  //Future<List<String>> listSeedFingerprints();
  Future<List<Secret>> loadAll();
  Future<bool> exists(Fingerprint fingerprint);
  Future<void> delete(Fingerprint fingerprint);
}
