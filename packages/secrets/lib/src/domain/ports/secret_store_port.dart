import 'dart:typed_data';

/// What a [SecretStore] backend can guarantee. Lets the package assert a
/// capability baseline (e.g. never downgrade `thisDeviceOnly`).
class StoreCapabilities {
  const StoreCapabilities({
    required this.hardwareBacked,
    required this.thisDeviceOnly,
    required this.syncable,
  });

  /// Keys are protected by a hardware security module (at rest + retrieval).
  final bool hardwareBacked;

  /// Secrets never leave the device (no iCloud/Google backup, no migration off).
  final bool thisDeviceOnly;

  /// Secrets are synced across the user's devices.
  final bool syncable;
}

/// INTERNAL port (never exported from the barrel) — the single swappable seam
/// for secret storage. Deliberately **use-and-forget shaped** (no `read()`, no
/// `getAll()`) so a future hardware backend (oubliette) drops in unchanged.
///
/// The only implementation today is `FssSecretStore` (flutter_secure_storage).
abstract interface class SecretStore {
  /// Idempotent backend initialization.
  Future<void> init();

  /// Store [value] under [key]. Throws if [key] already exists (oubliette
  /// parity — a store is never a silent overwrite).
  Future<void> store(String key, Uint8List value);

  /// Read the bytes for [key], hand them to [use], and return its result.
  /// There is intentionally no plain `read` — minimizing the secret's lifetime
  /// is the whole point of this shape. Callers are lint-allow-listed to
  /// `src/crypto/*`.
  Future<R> useAndForget<R>(
      String key, Future<R> Function(Uint8List bytes) use);

  Future<bool> exists(String key);

  /// Remove a single [key].
  Future<void> trash(String key);

  /// Wipe ALL secrets (logout / reset).
  Future<void> purge();

  /// Enumerate stored keys, INCLUDING legacy raw-fingerprint / `hiveEncryption`
  /// / `swapTxSensitive_*` keys, so startup reconciliation against the
  /// non-secret index can self-heal (a key with no index entry) and surface
  /// (an index entry with no key) rather than silently lose funds.
  Future<List<String>> keys();

  StoreCapabilities capabilities();
}
