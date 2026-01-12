import 'package:bb_mobile/core/primitives/secrets/secret.dart';

// Named store instead of repository since it only handles the secrets themselves,
// and doesn't have any complex querying capabilities.
abstract interface class LegacySecretStorePort {
  Future<List<Secret>> loadAll();
}
