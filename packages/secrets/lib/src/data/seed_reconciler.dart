import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/datasources/fss_secret_store.dart';
import 'package:secrets/src/domain/seed_index.dart';
import 'package:secrets/src/storage/secret_store.dart';

/// The outcome of reconciling the non-secret [SeedIndex] against the
/// [SecretStore]. Removing `getAll` from the secret store means the index is
/// the source of truth for enumeration — so a drift between the two must be
/// caught, never silently lose a seed (= lose funds).
class ReconcileReport {
  const ReconcileReport({
    required this.orphanSeedFingerprints,
    required this.danglingIndexFingerprints,
    this.malformedKeys = const [],
  });

  /// Seed keys present in the store but absent from the index. Self-heal: the
  /// caller reads each (via the repository) and upserts a `SeedInfo`.
  final List<Fingerprint> orphanSeedFingerprints;

  /// Index entries with no backing seed key. SURFACE these (a locked keychain
  /// or a real loss) — never drop them, or a transient lock reads as deletion.
  final List<Fingerprint> danglingIndexFingerprints;

  /// Seed-shaped keys whose fingerprint could not be parsed (storage
  /// corruption). Surfaced rather than silently dropped — a "never silently
  /// lose a seed" component must not hide a mangled key.
  final List<String> malformedKeys;

  bool get isClean =>
      orphanSeedFingerprints.isEmpty &&
      danglingIndexFingerprints.isEmpty &&
      malformedKeys.isEmpty;
}

/// Compares the index against the store and reports drift. Pure logic over the
/// two ports — does not mutate either; the caller decides how to heal/surface.
Future<ReconcileReport> reconcileSeeds({
  required SeedIndex index,
  required SecretStore store,
}) async {
  final storeFingerprints = <Fingerprint>{};
  final malformed = <String>[];
  for (final key in await store.keys()) {
    if (!SecretStoreKeys.isSeedKey(key)) continue;
    final hex = key.startsWith(SecretStoreKeys.seed)
        ? key.substring(SecretStoreKeys.seed.length)
        : key; // legacy raw-fingerprint key
    final fp = Fingerprint.tryParse(hex);
    if (fp != null) {
      storeFingerprints.add(fp);
    } else {
      malformed.add(key); // surface, never silently drop
    }
  }

  final indexFingerprints =
      (await index.all()).map((i) => i.fingerprint).toSet();

  return ReconcileReport(
    orphanSeedFingerprints:
        storeFingerprints.difference(indexFingerprints).toList(),
    danglingIndexFingerprints:
        indexFingerprints.difference(storeFingerprints).toList(),
    malformedKeys: malformed,
  );
}
