import 'dart:typed_data';

import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart'
    show SecretStoreKeys;
import 'package:secrets/src/data/datasources/secret_not_found_exception.dart';
import 'package:secrets/src/domain/ports/secret_index_port.dart';
import 'package:secrets/src/domain/ports/secret_store_port.dart';

/// The outcome of one FSS→hardware migration pass. Pure data — the package never
/// logs; the app `log.shout`s this for the per-device migration census.
class MigrationReport {
  const MigrationReport({
    required this.migrated,
    required this.skipped,
    required this.failures,
  });

  /// Secrets newly copied into the hardware backend this pass.
  final int migrated;

  /// Secrets already present in the hardware backend (idempotent re-run).
  final int skipped;

  /// Per-secret failures, each with the fingerprint and the exception's runtime
  /// type name (never a message — no secret material). A dangling index entry
  /// (a fingerprint in neither store) lands here as `SecretNotFoundException`.
  /// A seed key present in FSS but ABSENT from the index (an un-healed orphan)
  /// lands here as `fss_orphan_not_indexed` — so `complete` cannot read true
  /// while FSS still holds seed material the index-driven pass never migrated.
  final List<({Fingerprint fingerprint, String errorType})> failures;

  /// True only when every indexed seed migrated AND no un-indexed FSS seed key
  /// remains. A completeness-gated FSS removal keys off this — so it must stay
  /// false whenever FSS still holds material that would be destroyed. Run
  /// `Secrets.reconcile()` before migrating so orphans are healed into the index
  /// (and thus actually migrated) rather than reported here.
  bool get complete => failures.isEmpty;

  /// Gate for the census shout: only emit when a pass actually did something, so
  /// a fully-migrated device is silent and a failing one keeps reporting.
  bool get didWork => migrated > 0 || failures.isNotEmpty;

  int get total => migrated + skipped + failures.length;
}

/// Copies every indexed secret not yet in [_hw] from [_fss] into [_hw], one at a
/// time, verifying each by reading the stored bytes back and comparing. FSS
/// copies are NOT trashed — FSS stays a safety net until removed wholesale.
/// Index-driven (a deleted/index-removed seed is never resurrected). Idempotent
/// (already-migrated are skipped → a re-run retries only failures). Per-secret
/// errors are collected, never thrown, so one bad seed never aborts the rest.
class SecretMigrator {
  SecretMigrator({
    required SecretStorePort hardware,
    required SecretStorePort fallback,
    required SecretIndexPort index,
  })  : _hw = hardware,
        _fss = fallback,
        // ignore: prefer_initializing_formals — symmetric with hardware/fallback
        _index = index;

  final SecretStorePort _hw;
  final SecretStorePort _fss;
  final SecretIndexPort _index;

  Future<MigrationReport> run() async {
    var migrated = 0;
    var skipped = 0;
    final failures = <({Fingerprint fingerprint, String errorType})>[];

    final indexed = await _index.all();
    final indexedHexes = {for (final i in indexed) i.fingerprint.hex};

    for (final info in indexed) {
      final key = SecretStoreKeys.seedKey(info.fingerprint.hex);
      try {
        if (await _hw.exists(key)) {
          skipped++;
          continue;
        }
        // Read the FSS bytes OUT of the callback first (FSS zeroes `bytes`, not
        // our copy). We store to HW only AFTER re-checking the seed wasn't
        // deleted meanwhile — a delete (index.remove + trash) that races this
        // pass must never resurrect the seed in hardware. This narrows the
        // exists→read→store window that the migration-in-flight guard (which
        // only serializes migrations) leaves open against delete.
        Uint8List? original;
        await _fss.useAndForget(key, (bytes) async {
          original = Uint8List.fromList(bytes);
        });
        if (original == null) {
          failures.add((fingerprint: info.fingerprint, errorType: 'fss_empty'));
          continue;
        }
        if (await _index.get(info.fingerprint) == null) {
          // Deleted while we read it — do NOT re-create in hardware.
          original!.fillRange(0, original!.length, 0);
          continue;
        }
        await _hw.store(key, original!);
        // Verify by reading bytes back and comparing — a backend that acks
        // exists() but persists corrupt ciphertext passes a presence-only check.
        final originalBytes = original!;
        try {
          final verified = await _hw.useAndForget(key, (stored) async {
            if (stored.length != originalBytes.length) return false;
            for (var i = 0; i < stored.length; i++) {
              if (stored[i] != originalBytes[i]) return false;
            }
            return true;
          });
          if (verified) {
            migrated++;
          } else {
            failures.add((fingerprint: info.fingerprint, errorType: 'verify_mismatch'));
          }
        } on SecretNotFoundException {
          failures.add((fingerprint: info.fingerprint, errorType: 'verify_failed'));
        } finally {
          original!.fillRange(0, original!.length, 0);
        }
      } on Exception catch (e) {
        failures
            .add((fingerprint: info.fingerprint, errorType: e.runtimeType.toString()));
      }
    }

    // Census the FSS side for seed keys the INDEX-driven pass never saw (an
    // un-healed orphan). Their material would be destroyed by a completeness-
    // gated FSS removal, so record them as failures — `complete` must not read
    // true while they remain. Reconcile heals them into the index before this
    // pass; anything left here means reconcile hasn't run or couldn't decode it.
    try {
      for (final key in await _fss.keys()) {
        if (!SecretStoreKeys.isSeedKey(key)) continue;
        final hex = key.startsWith(SecretStoreKeys.seed)
            ? key.substring(SecretStoreKeys.seed.length)
            : key; // legacy bare-fingerprint key
        if (indexedHexes.contains(hex)) continue; // already covered above
        final fp = Fingerprint.tryParse(hex);
        failures.add((
          fingerprint: fp ?? Fingerprint('00000000'),
          errorType: 'fss_orphan_not_indexed',
        ));
      }
    } on Exception catch (e) {
      // Enumeration itself failed (e.g. locked) — surface it so `complete` is
      // false rather than falsely clean.
      failures.add((
        fingerprint: Fingerprint('00000000'),
        errorType: e.runtimeType.toString(),
      ));
    }

    return MigrationReport(
      migrated: migrated,
      skipped: skipped,
      failures: failures,
    );
  }
}
