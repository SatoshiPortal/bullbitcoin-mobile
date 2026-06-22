import 'package:primitives/primitives.dart';

import 'package:secrets/src/domain/value_objects/seed_info.dart';

/// INJECTED port: the non-secret index of which seeds exist. `secrets` defines
/// the interface; the APP implements it with a Drift `seed_index` table (Drift
/// codegen stays app-side — the package does not own the app DB schema).
///
/// This replaces enumerate-by-`getAll` on the secret store: the future
/// hardware backend (oubliette) has no `getAll`, so the list of seeds must live
/// in a non-secret index, reconciled against `SecretStorePort.keys()` at startup.
abstract interface class SeedIndexPort {
  Future<void> upsert(SeedInfo info);
  Future<List<SeedInfo>> all();
  Future<SeedInfo?> get(Fingerprint fp);
  Future<void> remove(Fingerprint fp);
}
