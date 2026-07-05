import 'package:primitives/primitives.dart';

/// The outcome of a startup reconciliation pass (`Secrets.reconcile`). Pure,
/// secret-free data — the app `log.shout`s it, exactly like `MigrationReport`.
///
/// Reconciliation heals the drift that a non-atomic `store → index.upsert` (or a
/// lost/rebuilt index database) can leave behind: a secret present in the store
/// but absent from the index is invisible to `fetch`/`list` (index-driven), so
/// it is re-indexed here. Without this pass such a seed — and, if the whole index
/// DB is lost, EVERY seed — would be unreachable despite the material still
/// existing on-device.
class ReconcileReport {
  const ReconcileReport({
    required this.healed,
    required this.danglingFingerprints,
    required this.legacyKeys,
    required this.malformedKeys,
    required this.failures,
  });

  /// Orphans (under the `seed_<fp>` scheme, missing from the index) successfully
  /// re-indexed.
  final int healed;

  /// Index entries with no backing store key — SURFACED, never dropped: a
  /// transient keychain lock or a real loss both land here, and treating a lock
  /// as a deletion would strand funds. The app decides how to react (re-probe,
  /// prompt), but must not silently remove them.
  final List<Fingerprint> danglingFingerprints;

  /// Store keys under the pre-`seed_` legacy scheme. The package can't operate on
  /// them, so it never heals them — the app's migration re-keys them. Surfaced
  /// for telemetry (expected empty once migration has run).
  final List<String> legacyKeys;

  /// Seed-shaped store keys whose fingerprint could not be parsed (storage
  /// corruption). Surfaced, never silently dropped.
  final List<String> malformedKeys;

  /// Orphans that could NOT be re-indexed this pass (e.g. a locked keychain, or
  /// a malformed stored blob), carrying only the exception's runtime *type* name
  /// — never secret-bearing text. Collected, never thrown: one bad orphan never
  /// aborts the rest, and a re-run retries only these.
  final List<({Fingerprint fingerprint, String errorType})> failures;

  /// Nothing to report — the index and store already agree and nothing failed.
  bool get isClean =>
      healed == 0 &&
      danglingFingerprints.isEmpty &&
      legacyKeys.isEmpty &&
      malformedKeys.isEmpty &&
      failures.isEmpty;

  /// Gate the telemetry shout: emit only when the pass actually did or found
  /// something, so a steady-state launch stays silent.
  bool get didWork => !isClean;
}
