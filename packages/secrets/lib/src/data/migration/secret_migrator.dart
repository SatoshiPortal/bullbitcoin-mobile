import 'dart:typed_data';

import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart'
    show SecretStoreKeys;
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
  final List<({Fingerprint fingerprint, String errorType})> failures;

  bool get complete => failures.isEmpty;

  /// Gate for the census shout: only emit when a pass actually did something, so
  /// a fully-migrated device is silent and a failing one keeps reporting.
  bool get didWork => migrated > 0 || failures.isNotEmpty;

  int get total => migrated + skipped + failures.length;
}

/// Copies every indexed secret not yet in [_hw] from [_fss] into [_hw], one at a
/// time, verifying each. FSS copies are NOT trashed — FSS stays a safety net
/// until removed wholesale. Index-driven (a deleted/index-removed seed is never
/// resurrected). Idempotent (already-migrated are skipped → a re-run retries
/// only failures). Per-secret errors are collected, never thrown, so one bad
/// seed never aborts the rest.
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

    for (final info in await _index.all()) {
      final key = SecretStoreKeys.seedKey(info.fingerprint.hex);
      try {
        if (await _hw.exists(key)) {
          skipped++;
          continue;
        }
        await _fss.useAndForget(key, (bytes) async {
          // FSS zeroes `bytes` after this callback; `copy` is ours to zero.
          final copy = Uint8List.fromList(bytes);
          try {
            await _hw.store(key, copy);
          } finally {
            copy.fillRange(0, copy.length, 0);
          }
        });
        if (await _hw.exists(key)) {
          migrated++;
        } else {
          failures.add((fingerprint: info.fingerprint, errorType: 'verify_failed'));
        }
      } on Exception catch (e) {
        failures
            .add((fingerprint: info.fingerprint, errorType: e.runtimeType.toString()));
      }
    }

    return MigrationReport(
      migrated: migrated,
      skipped: skipped,
      failures: failures,
    );
  }
}
