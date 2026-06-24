import 'package:primitives/primitives.dart';

import 'package:secrets/src/domain/value_objects/secret_info.dart';

/// INJECTED port: the non-secret index of which secrets exist. `secrets` defines
/// the interface; the APP implements it with a Drift `seed_index` table (Drift
/// codegen stays app-side — the package does not own the app DB schema).
///
/// This replaces enumerate-by-`getAll` on the secret store: the future
/// hardware backend (oubliette) has no `getAll`, so the list of secrets must
/// live in a non-secret index, reconciled against `SecretStorePort.keys()` at
/// startup.
abstract interface class SecretIndexPort {
  Future<void> upsert(SecretInfo info);
  Future<List<SecretInfo>> all();
  Future<SecretInfo?> get(Fingerprint fp);
  Future<void> remove(Fingerprint fp);
}
