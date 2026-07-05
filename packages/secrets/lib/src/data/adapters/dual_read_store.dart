import 'dart:typed_data';

import 'package:secrets/src/data/datasources/secret_not_found_exception.dart';
import 'package:secrets/src/data/migration/secret_migrator.dart';
import 'package:secrets/src/domain/ports/secret_index_port.dart';
import 'package:secrets/src/domain/ports/secret_store_port.dart';

/// Reads the hardware backend (oubliette) first, falls back to FSS; NEW writes
/// go to hardware only. There is NO migrate-on-read — bulk migration is an
/// explicit, quiesced pass ([migratePending] → [SecretMigrator]), so this
/// decorator never writes during a read and needs no per-key lock or purge
/// gate. FSS is a read fallback + safety net until it is removed wholesale.
class DualReadStore implements SecretStorePort {
  DualReadStore({
    required SecretStorePort hardware,
    required SecretStorePort fallback,
  })  : _hw = hardware,
        _fss = fallback;

  final SecretStorePort _hw;
  final SecretStorePort _fss;

  @override
  Future<void> init() async {
    await _hw.init();
    await _fss.init();
  }

  /// Reports the HARDWARE capabilities. NOTE: this is a per-store baseline, not a
  /// per-seed guarantee — during the dual period un-migrated seeds still live in
  /// FSS (`hardwareBacked: false`), so `hardwareBacked: true` is aspirational
  /// until migration completes and FSS is removed (Phase 4). Nothing gates on it
  /// today; a future "require hardwareBacked" assertion must not be added before
  /// FSS is gone, or it would pass falsely while seeds remain in FSS.
  @override
  StoreCapabilities capabilities() => _hw.capabilities();

  /// New secrets are hardware-backed from creation.
  @override
  Future<void> store(String key, Uint8List value) => _hw.store(key, value);

  @override
  Future<R> useAndForget<R>(
    String key,
    Future<R> Function(Uint8List bytes) use,
  ) async {
    // DELIBERATE: fall back to FSS on a hardware MISS only — NOT on a hardware
    // read FAILURE (KeyInvalidated / Decryption / lock). Those surface as typed
    // failures so the app can telemeter hardware-degradation rates; that signal
    // is exactly what decision #3 needs to judge when FSS can be removed. Silently
    // masking a hardware failure with the retained FSS copy would inflate the
    // compatibility census and risk killing FSS on falsely-clean data. A migrated
    // seed whose hardware key is invalidated is still recoverable from its FSS
    // copy, but that recovery is an explicit app-side policy on KeyInvalidatedFailure,
    // not a silent read-path fallback (§2.3).
    //
    // A SecretNotFoundException is a hardware MISS only if `use` never ran. If
    // `use` (or anything below it) threw it after receiving the bytes, the key
    // WAS in hardware — rethrow, don't fall back or re-invoke `use`. Without
    // this guard a closure that raised SecretNotFoundException would be re-run
    // on FSS (double invocation — unsafe for a signing closure).
    var used = false;
    Future<R> once(Uint8List b) {
      used = true;
      return use(b);
    }

    try {
      return await _hw.useAndForget(key, once);
    } on SecretNotFoundException {
      if (used) rethrow;
    }
    return _fss.useAndForget(key, use); // un-migrated seed → read from FSS
  }

  @override
  Future<bool> exists(String key) async =>
      (await _hw.exists(key)) || (await _fss.exists(key));

  /// Remove from both, FSS (the migration source) first: if FSS fails we have
  /// not touched hardware (state stays consistent, the delete is reported as
  /// failed, the user retries); if FSS succeeds, no later read can re-migrate,
  /// so a subsequent hardware-trash failure cannot be undone by a resurrection.
  @override
  Future<void> trash(String key) async {
    await _fss.trash(key);
    await _hw.trash(key);
  }

  /// Wipe both, FSS (the migration source) FIRST — same ordering rationale as
  /// [trash]: if FSS purge fails we have not touched hardware (state stays
  /// consistent, the purge reports failed, the caller retries); if FSS succeeds,
  /// no later read can re-migrate, so a subsequent hardware-purge failure cannot
  /// be undone by a resurrection. The inverse (HW-first) would leave the FSS
  /// copies readable/re-migratable if the FSS purge then failed.
  @override
  Future<void> purge() async {
    await _fss.purge();
    await _hw.purge();
  }

  @override
  Future<List<String>> keys() async =>
      {...await _hw.keys(), ...await _fss.keys()}.toList(growable: false);

  /// One-time FSS→hardware migration (an explicit, quiesced pass — see
  /// [SecretMigrator]). Returns counts + per-secret failures for the caller to
  /// telemeter; FSS copies are retained.
  Future<MigrationReport> migratePending(SecretIndexPort index) =>
      SecretMigrator(hardware: _hw, fallback: _fss, index: index).run();
}
