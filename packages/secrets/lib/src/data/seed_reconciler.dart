import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart';
import 'package:secrets/src/domain/ports/secret_index_port.dart';
import 'package:secrets/src/domain/ports/secret_store_port.dart';

/// The drift detected between the non-secret [SecretIndexPort] and the
/// [SecretStorePort]. Removing `getAll` from the secret store means the index is
/// the source of truth for enumeration — so a drift between the two must be
/// caught, never silently lose a seed (= lose funds).
///
/// This is the internal *detection* result; the app-facing *heal outcome* is the
/// public `ReconcileReport` (produced by `SecretLifecycleAdapter.reconcile`).
class SeedDrift {
  const SeedDrift({
    required this.orphanSeedFingerprints,
    required this.danglingIndexFingerprints,
    this.legacyStoreKeys = const [],
    this.malformedKeys = const [],
  });

  /// Keys under the package's `seed_<fp>` scheme present in the store but absent
  /// from the index. Self-heal: the caller reads each (via the repository) and
  /// upserts a `SecretInfo`. Legacy bare-fingerprint keys are NOT included here
  /// (see [legacyStoreKeys]) — the package reads only `seed_<fp>`, so it could
  /// index them but never operate on them.
  final List<Fingerprint> orphanSeedFingerprints;

  /// Index entries with no backing seed key (under EITHER scheme). SURFACE these
  /// (a locked keychain or a real loss) — never drop them, or a transient lock
  /// reads as deletion.
  final List<Fingerprint> danglingIndexFingerprints;

  /// Store keys under the pre-`seed_` legacy bare-fingerprint scheme. The package
  /// owns only `seed_<fp>`; re-keying these is the app's migration-005 job.
  /// Surfaced for telemetry (they should be absent by the time reconcile runs),
  /// never healed — indexing one would produce an entry the package can't read.
  final List<String> legacyStoreKeys;

  /// Seed-shaped keys whose fingerprint could not be parsed (storage
  /// corruption). Surfaced rather than silently dropped — a "never silently
  /// lose a seed" component must not hide a mangled key.
  final List<String> malformedKeys;

  bool get isClean =>
      orphanSeedFingerprints.isEmpty &&
      danglingIndexFingerprints.isEmpty &&
      legacyStoreKeys.isEmpty &&
      malformedKeys.isEmpty;
}

/// Compares the index against the store and reports drift. Pure logic over the
/// two ports — does not mutate either; the caller decides how to heal/surface.
Future<SeedDrift> reconcileSeeds({
  required SecretIndexPort index,
  required SecretStorePort store,
}) async {
  // `seed_<fp>`-scheme fingerprints (healable) are kept apart from legacy
  // bare-fingerprint keys (surfaced, not healable): the package reads only
  // `seed_<fp>`, so indexing a legacy key would yield an entry it can't operate
  // on. Both sets back the store, so both count against dangling detection.
  final prefixedFingerprints = <Fingerprint>{};
  final legacyFingerprints = <Fingerprint>{};
  final legacyKeys = <String>[];
  final malformed = <String>[];
  for (final key in await store.keys()) {
    if (!SecretStoreKeys.isSeedKey(key)) continue;
    if (!key.startsWith(SecretStoreKeys.seed)) {
      legacyKeys.add(key); // legacy bare-fingerprint key — app's to migrate
      final fp = Fingerprint.tryParse(key);
      if (fp != null) legacyFingerprints.add(fp);
      continue;
    }
    final hex = key.substring(SecretStoreKeys.seed.length);
    final fp = Fingerprint.tryParse(hex);
    if (fp != null) {
      prefixedFingerprints.add(fp);
    } else {
      malformed.add(key); // surface, never silently drop
    }
  }

  final indexFingerprints =
      (await index.all()).map((i) => i.fingerprint).toSet();
  final backedFingerprints = prefixedFingerprints.union(legacyFingerprints);

  return SeedDrift(
    orphanSeedFingerprints:
        prefixedFingerprints.difference(indexFingerprints).toList(),
    danglingIndexFingerprints:
        indexFingerprints.difference(backedFingerprints).toList(),
    legacyStoreKeys: legacyKeys,
    malformedKeys: malformed,
  );
}
