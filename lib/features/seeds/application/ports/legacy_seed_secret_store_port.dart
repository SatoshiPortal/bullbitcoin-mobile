import 'package:bb_mobile/core/primitives/seeds/seed_secret.dart';

// Named store instead of repository since it only handles the secrets themselves,
// and doesn't have any complex querying capabilities.
abstract interface class LegacySeedSecretStorePort {
  Future<List<SeedSecret>> loadAll();
}
