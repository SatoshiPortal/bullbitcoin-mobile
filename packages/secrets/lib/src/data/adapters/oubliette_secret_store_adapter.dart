import 'dart:typed_data';

import 'package:flutter/services.dart' show PlatformException;
import 'package:oubliette/oubliette.dart';
import 'package:secrets/src/data/datasources/hardware_key_invalidated_exception.dart';
import 'package:secrets/src/data/datasources/keychain_locked_exception.dart';
import 'package:secrets/src/data/datasources/malformed_secret_exception.dart';
import 'package:secrets/src/data/datasources/secret_not_found_exception.dart';
import 'package:secrets/src/domain/ports/secret_store_port.dart';

/// A [SecretStorePort] backed by oubliette (hardware-backed, device-local).
///
/// Wired only on iOS/Android by the package (where oubliette is genuinely
/// hardware-backed). Translates the sealed [OublietteException] family into the
/// package's internal exception vocabulary so [SecretGuard] can map them to
/// typed `SecretsFailure`s without knowing about oubliette, and maps oubliette's
/// null-on-absent `useAndForget` convention to [SecretNotFoundException] (the
/// shape [FssSecretStoreAdapter] already uses).
class OublietteSecretStoreAdapter implements SecretStorePort {
  const OublietteSecretStoreAdapter(this._o);

  final Oubliette _o;

  @override
  Future<void> init() async {
    try {
      await _o.init();
    } on OublietteException catch (e) {
      throw _translate(e, null);
    } on PlatformException catch (e) {
      throw _classifyRaw(e);
    }
  }

  // hardwareBacked is true on both platforms this adapter is wired (iOS class
  // keys, Android TEE); thisDeviceOnly / !syncable are oubliette invariants.
  @override
  StoreCapabilities capabilities() => const StoreCapabilities(
        hardwareBacked: true,
        thisDeviceOnly: true,
        syncable: false,
      );

  @override
  Future<void> store(String key, Uint8List value) async {
    try {
      await _o.store(key, value);
    } on StateError {
      // oubliette throws StateError on a duplicate (write-once); unify with the
      // package's typed "already exists" so the lifecycle layer maps it to a
      // benign DuplicateSecretFailure.
      throw SecretAlreadyExistsException(key);
    } on OublietteException catch (e) {
      throw _translate(e, key);
    } on PlatformException catch (e) {
      throw _classifyRaw(e);
    }
  }

  /// [R] must be non-void: a void action returns null even on a hit, which would
  /// wrongly raise [SecretNotFoundException]. Every BULL caller returns a
  /// concrete non-nullable type, so this holds in practice.
  @override
  Future<R> useAndForget<R>(
    String key,
    Future<R> Function(Uint8List bytes) use,
  ) async {
    try {
      final result = await _o.useAndForget(key, use);
      if (result == null) throw SecretNotFoundException(key);
      return result;
    } on OublietteException catch (e) {
      throw _translate(e, key);
    } on PlatformException catch (e) {
      throw _classifyRaw(e);
    }
  }

  @override
  Future<bool> exists(String key) async {
    try {
      return await _o.exists(key);
    } on OublietteException catch (e) {
      throw _translate(e, key);
    } on PlatformException catch (e) {
      throw _classifyRaw(e);
    }
  }

  @override
  Future<void> trash(String key) async {
    try {
      await _o.trash(key);
    } on OublietteException catch (e) {
      throw _translate(e, key);
    } on PlatformException catch (e) {
      throw _classifyRaw(e);
    }
  }

  /// No re-init: oubliette re-mints the key lazily on the next `store` (Android
  /// `_ensureKey`), and iOS has no app-managed key. Reads after purge correctly
  /// return not-found.
  @override
  Future<void> purge() async {
    try {
      await _o.purge();
    } on OublietteException catch (e) {
      throw _translate(e, null);
    } on PlatformException catch (e) {
      throw _classifyRaw(e);
    }
  }

  @override
  Future<List<String>> keys() async {
    try {
      return await _o.keys();
    } on OublietteException catch (e) {
      throw _translate(e, null);
    } on PlatformException catch (e) {
      throw _classifyRaw(e);
    }
  }

  /// A reserved sentinel key — NOT a `seed_*` key, so reconciliation ignores it.
  static const _probeKey = '__probe__';

  /// A self-contained capability probe: a full `init → trash → store → read-back
  /// → verify` round-trip on the sentinel (never a real secret). Returns true iff
  /// the round-trip proves oubliette is usable on this device.
  ///
  /// Confined to this adapter (a [SecretStorePort] implementation) so the only
  /// raw-secret `useAndForget` call sites stay the guard + the sealed UI reader —
  /// the probe reads back only its own 2-byte sentinel. A translated failure
  /// (locked vs. structural) propagates for the caller to classify; cleanup is
  /// best-effort and never downgrades a decided outcome (a trailing trash that
  /// trips a transient lock must not turn a capable device into "deferred" — any
  /// residual sentinel is cleared by the trash-before-store on the next probe).
  Future<bool> probeRoundTrip() async {
    final bytes = Uint8List.fromList(const [0x0b, 0xb1]);
    await init();
    await trash(_probeKey); // clear any stale sentinel (idempotent)
    await store(_probeKey, bytes);
    final ok = await useAndForget(
      _probeKey,
      (b) async => b.length == 2 && b[0] == bytes[0] && b[1] == bytes[1],
    );
    try {
      await trash(_probeKey);
    } on Exception {
      // ignore — outcome already determined; sentinel cleared next probe.
    }
    return ok;
  }

  /// Exhaustive over the sealed [OublietteException]. Carries only the runtime
  /// type name into [MalformedSecretException] — never `cause`/`keyAlias`, which
  /// can hold OEM/biometric text or caller-sensitive identifiers.
  ///
  /// INVARIANT (pinned by `recoverable_translation_test.dart`): every
  /// `recoverable` subtype must map to [KeychainLockedException] and every
  /// non-recoverable one to a structural type. The capability probe re-derives
  /// "defer vs. mark-incompatible" from that line (§2.5), so a future recoverable
  /// subtype mis-mapped here would permanently strand a transiently-locked device
  /// on FSS. The drift guard fails CI if this switch and `e.recoverable` disagree.
  Exception _translate(OublietteException e, String? key) => switch (e) {
        AuthenticationFailedException() => const KeychainLockedException(),
        KeyringLockedException() => const KeychainLockedException(),
        BackendUnavailableException() => const KeychainLockedException(),
        KeyInvalidatedException() => HardwareKeyInvalidatedException(key: key),
        KeyNotFoundException() => HardwareKeyInvalidatedException(key: key),
        DecryptionFailedException() =>
          MalformedSecretException(e.runtimeType.toString()),
        PayloadTamperException() =>
          MalformedSecretException(e.runtimeType.toString()),
        PayloadCorruptException() =>
          MalformedSecretException(e.runtimeType.toString()),
      };

  /// Oubliette leaves a few codes raw (`strongbox_unavailable` /
  /// `hardware_unavailable` — only with `strongBox`/`requireHardwareBacking`
  /// set, i.e. not phase 1 — `bad_args`, unknown OEM codes). Classify a locked
  /// signal as such; rethrow the rest so a genuine config error/bug surfaces
  /// (SecretGuard maps an unknown to SecretsUnexpectedFailure, never a silent
  /// not-found).
  Exception _classifyRaw(PlatformException e) =>
      isKeychainLockedError(e) ? const KeychainLockedException() : e;
}
