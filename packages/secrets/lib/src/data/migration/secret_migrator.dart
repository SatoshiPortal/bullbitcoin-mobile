import 'dart:typed_data';

import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart'
    show SecretStoreKeys;
import 'package:secrets/src/data/datasources/secret_not_found_exception.dart';
import 'package:secrets/src/data/models/mnemonic.dart';
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
      final fp = info.fingerprint;
      final key = SecretStoreKeys.seedKey(fp.hex);
      Uint8List? original;
      try {
        // ── Already in hardware: DON'T trust presence. A crash between a prior
        //    store and its verify, or a backend that acked a corrupt write,
        //    leaves an unverified HW copy that oubliette (write-once) can't
        //    repair — and it SHADOWS the good FSS copy (DualReadStore falls back
        //    only on miss, not read-failure). So while an FSS copy still exists,
        //    byte-verify HW against it. On a mismatch we must NOT assume the
        //    (weaker, more corruptible) FSS copy is authoritative — the master
        //    fingerprint (== the storage key) arbitrates which side is the real
        //    seed. Only the mis-fingerprinted side is ever trashed/re-migrated;
        //    a fingerprint-verified copy is never destroyed. ────────────────────
        if (await _hw.exists(key)) {
          final verdict = await _verifyHwAgainstFss(key, fp);
          switch (verdict) {
            case _HwCheck.match:
            case _HwCheck.noFss:
            case _HwCheck.hwAuthentic:
              skipped++; // matches, no FSS to compare, or HW is the real copy
              continue;
            case _HwCheck.unverifiable:
              // Bytes differ and NEITHER copy fingerprint-matches the key (or HW
              // is only unreadable, possibly locked). We cannot tell which is
              // real, so DESTROY NOTHING and keep `complete` false.
              failures.add((fingerprint: fp, errorType: 'hw_fss_unverifiable'));
              continue;
            case _HwCheck.reMigrate:
              // HW is definitively corrupt (decoded to the wrong fingerprint)
              // and FSS is fingerprint-verified → trash HW, re-migrate FSS.
              await _tryTrash(key);
          }
        }

        // Read the FSS bytes OUT of the callback (FSS zeroes `bytes`, not our
        // copy). Store to HW only AFTER re-checking the seed wasn't deleted
        // meanwhile: a delete trashes the FSS copy (and HW) BEFORE removing the
        // index, so we re-check BOTH the FSS store and the index — either one
        // gone means a delete is in flight and we must NOT resurrect the seed.
        await _fss.useAndForget(key, (bytes) async {
          original = Uint8List.fromList(bytes);
        });
        if (original == null) {
          failures.add((fingerprint: fp, errorType: 'fss_empty'));
          continue;
        }
        if (!await _fss.exists(key) || await _index.get(fp) == null) {
          continue; // deleted while we read it — `finally` zeroes `original`
        }

        await _hw.store(key, original!);
        // Verify by reading bytes back — a backend that acks the write but
        // persists corrupt/truncated ciphertext passes a presence-only check.
        // ANY failure here (mismatch, not-found, corrupt-ciphertext decode)
        // trashes the just-written HW copy so a re-run retries cleanly instead
        // of counting the poison `skipped`.
        try {
          if (await _readBackMatches(key, original!)) {
            // POST-STORE TOCTOU guard: the pre-store re-check (above) does not
            // serialize against a concurrent delete(), which trashes FSS+HW and
            // THEN removes the index. A delete completing in the store/verify
            // window means `_hw.store` just RESURRECTED a seed the user deleted —
            // with no index entry, so the next reconcile() would re-index it and
            // the deleted seed returns. Re-check the delete markers now; if the
            // seed is gone from FSS or the index, trash the copy we just wrote
            // instead of counting it migrated. (The residual race — a delete
            // interleaving right after this re-check — needs a lock shared with
            // the delete path; this closes the common ordering.)
            if (!await _fss.exists(key) || await _index.get(fp) == null) {
              await _tryTrash(key);
              continue; // deleted during migration — do not resurrect
            }
            migrated++;
          } else {
            await _tryTrash(key);
            failures.add((fingerprint: fp, errorType: 'verify_mismatch'));
          }
        } on Exception catch (e) {
          await _tryTrash(key);
          failures.add((fingerprint: fp, errorType: 'verify_failed:${e.runtimeType}'));
        }
      } on Exception catch (e) {
        failures.add((fingerprint: fp, errorType: e.runtimeType.toString()));
      } finally {
        if (original != null) original!.fillRange(0, original!.length, 0);
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

  /// Verifies an already-present HW copy against the retained FSS copy, using
  /// the master fingerprint [expected] (== the storage key) to arbitrate a
  /// mismatch so the weaker FSS store is never trusted as ground truth:
  ///   `match`       = bytes agree;
  ///   `noFss`       = no FSS copy to compare (trust HW — never destroy the only
  ///                   copy);
  ///   `hwAuthentic` = bytes differ but HW decodes to [expected] — HW is the real
  ///                   seed; FSS is the corrupt/variant copy, so keep HW as-is;
  ///   `reMigrate`   = HW decodes to the WRONG fingerprint and FSS decodes to
  ///                   [expected] — HW is corrupt, FSS is authentic → re-migrate;
  ///   `unverifiable`= HW unreadable, or neither copy fingerprint-matches — we
  ///                   can't tell which is real, so destroy nothing.
  Future<_HwCheck> _verifyHwAgainstFss(String key, Fingerprint expected) async {
    Uint8List? fssCopy;
    try {
      await _fss.useAndForget(key, (b) async {
        fssCopy = Uint8List.fromList(b);
      });
    } on SecretNotFoundException {
      return _HwCheck.noFss; // FSS already removed — can't compare, trust HW
    }
    if (fssCopy == null) return _HwCheck.noFss;
    try {
      if (await _readBackMatches(key, fssCopy!)) return _HwCheck.match;
    } on Exception {
      // HW copy unreadable — do NOT conclude "HW is bad, FSS wins"; fall through
      // to fingerprint arbitration below.
    } finally {
      fssCopy!.fillRange(0, fssCopy!.length, 0);
    }
    // Bytes differ (or HW was unreadable). Let the fingerprint decide which copy
    // is the authentic seed — never re-migrate an FSS copy that fails to derive
    // `expected` (that would overwrite a good HW seed with corruption and still
    // pass the byte-for-byte read-back check).
    final hwOk = await _decodesToFingerprint(_hw, key, expected);
    if (hwOk == true) return _HwCheck.hwAuthentic; // HW is real; FSS is the bad copy
    final fssOk = await _decodesToFingerprint(_fss, key, expected);
    if (hwOk == false && fssOk == true) return _HwCheck.reMigrate;
    return _HwCheck.unverifiable; // HW unreadable, or neither fingerprint-matches
  }

  /// Reads [key] from [store] and reports whether it decodes to a mnemonic whose
  /// master fingerprint equals [expected]: `true` = authentic, `false` = decodes
  /// to the wrong fingerprint (or undecodable garbage — fail closed, not
  /// authentic), `null` = unreadable (locked/absent) so it is not a verdict.
  Future<bool?> _decodesToFingerprint(
      SecretStorePort store, String key, Fingerprint expected) async {
    try {
      return await store.useAndForget(key, (bytes) async {
        try {
          return Mnemonic.fromStorageBytes(Uint8List.fromList(bytes))
                  .fingerprint ==
              expected;
        } catch (_) {
          return false; // undecodable / underivable → not the authentic copy
        }
      });
    } on Exception {
      return null; // unreadable (locked / not found) — not a verdict
    }
  }

  /// Reads [key] back from hardware and byte-compares against [expected].
  Future<bool> _readBackMatches(String key, Uint8List expected) =>
      _hw.useAndForget(key, (stored) async {
        if (stored.length != expected.length) return false;
        for (var i = 0; i < stored.length; i++) {
          if (stored[i] != expected[i]) return false;
        }
        return true;
      });

  /// Best-effort HW trash of a bad/unverified copy — never throws (a trash
  /// failure must not abort the whole pass; the next re-run retries).
  Future<void> _tryTrash(String key) async {
    try {
      await _hw.trash(key);
    } on Exception {
      // ignore — re-run will re-attempt; the failure is already recorded.
    }
  }
}

enum _HwCheck { match, noFss, hwAuthentic, reMigrate, unverifiable }
