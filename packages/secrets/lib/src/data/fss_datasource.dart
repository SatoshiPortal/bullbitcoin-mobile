import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:bull_logger/bull_logger.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:synchronized/synchronized.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/exceptions.dart';
import 'package:secrets/src/data/models/key_model.dart';
import 'package:secrets/src/data/models/secret_model.dart';
import 'package:secrets/src/domain/domain.dart';

/// A stored entry, paired with the identity it was filed under.
///
/// The key matters: it *is* the master fingerprint, so carrying it out
/// of the store saves the repository from re-deriving one.
typedef StoredSecret = ({Fingerprint id, SecretModel model});

/// What a full read of the namespace yielded: the entries that parsed, and how many did not. The count is what lets a caller say "and N could not be read" rather than showing a shorter list as the whole truth.
typedef StoredListing = ({List<StoredSecret> parsed, int unparsable});

/// Everything this package puts in `flutter_secure_storage`, and the rules for getting it back.
///
/// The only holder of a `FlutterSecureStorage` instance here, and the only place that composes a key. Not exported, and `Secrets` builds it itself, so nothing outside can obtain the instance.
///
/// Two namespaces with deliberately different read semantics: a corrupt seed is skipped so it cannot hide the others, a corrupt module key is refused and kept. See the README, § The package owns the keystore.
///
/// **The lock is `static` and not reentrant**: the primitives ([_readRaw], [_writeRaw], [_deleteRaw], [_readAllRaw]) never take it, and a composed operation takes it exactly once and calls only primitives. A nested take hangs rather than throwing. Why it is per process and why single calls go unguarded: README, § One lock.
class FlutterSecureStorageDatasource {
  // --------------------------------------------------------------- keyspace

  /// Seeds. Historical prefix, kept verbatim: existing entries are
  /// written as `seed_<fingerprint>` and renaming it would hide every
  /// stored secret. Bare rather than reverse-DNS because it predates the
  /// convention below — do not "harmonise" the two.
  static const secretNamespace = 'seed_';

  /// Keys this package holds for other modules. Reverse-DNS so that no
  /// other component of the app — nor any plugin sharing the keystore —
  /// picks the same name by accident.
  static const keyNamespace = 'com.bullbitcoin.secrets';

  static String keyForSecret(Fingerprint id) => '$secretNamespace${id.hex}';

  /// The key is read from disk, so it is parsed, not trusted: `null` for anything that is not `seed_<8 hex>`.
  static Fingerprint? idFromKey(String key) =>
      Fingerprint.tryParse(key.substring(secretNamespace.length));

  /// Composes `com.bullbitcoin.secrets/<kind>/<package>/<name>`.
  ///
  /// The separator is `/` because a Dart package name may contain `_`:
  /// `dek_bull_payjoin_main` splits two ways, `dek/bull_payjoin/main`
  /// only one.
  static String keyForModule({
    required KeyKind kind,
    required String package,
    required String name,
  }) {
    for (final segment in [kind.wire, package, name]) {
      if (segment.isEmpty || segment.contains('/')) {
        throw ArgumentError.value(
          segment,
          'segment',
          'must be non-empty and free of "/"',
        );
      }
    }
    return '$keyNamespace/${kind.wire}/$package/$name';
  }

  // ----------------------------------------------------------------- plugin

  /// iOS keychain `OSStatus` for `errSecInteractionNotAllowed`, returned
  /// when the item's accessibility class requires the device to have
  /// been unlocked and it has not been. Historically this has surfaced
  /// in `details`, in `code` as a string, or inside `message`, so all
  /// three are matched — a plugin bump that shifts the field must not
  /// silently regress the whole locked/absent distinction.
  static const _errSecInteractionNotAllowed = -25308;

  static const _maxRetries = 5;
  static const _initialDelay = Duration(milliseconds: 300);

  final FlutterSecureStorage _storage;

  FlutterSecureStorageDatasource()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(
          // Never auto-delete on error and never migrate: both defaults
          // would risk destroying seed material, and the v10 line has a
          // history of migrations that could not be undone.
          resetOnError: false,
          migrateOnAlgorithmChange: false,
        ),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );

  // ------------------------------------------------------------------ secrets

  /// Writes a secret under its identity, refusing to replace a different one.
  ///
  /// A BIP32 fingerprint is 32 bits, so two secrets can claim the same key. Writing blind would destroy the first without a trace. Re-storing the same secret — a repeated import, a restore of a vault already held — is allowed and rewrites the same bytes.
  ///
  /// Read, compare and write under [_lock]: the second composed operation of this class, and the reason the lock is not named for the first.
  Future<void> storeSecret({
    required Fingerprint id,
    required SecretModel secret,
    required Future<Uint8List> Function(SecretModel model) seedOf,
  }) {
    final key = keyForSecret(id);
    final json = jsonEncode(secret.toJson());
    return _lock.synchronized(() async {
      final existing = await _readRaw(key);
      if (existing != null && existing.isNotEmpty) {
        if (!await _holdsSameSecret(existing, secret, seedOf)) {
          throw SecretIdentityConflict(
            'a different secret is already stored under $id',
          );
        }
        // The same secret, perhaps in an older encoding. Left byte for byte:
        // the format is frozen, and there is nothing to gain by rewriting.
        return;
      }
      await _writeRaw(key, json);
    });
  }

  /// Whether [existing] holds the same secret as [candidate] — parsed, not compared as text.
  ///
  /// An absent passphrase and an empty one are one secret, and a historical envelope may order its keys differently; comparing JSON would refuse both as "another secret". Same words with passphrases that differ *as strings* may still be one secret — `é` and `e` + combining accent are one passphrase to BIP39's NFKD (U1, Codex 2026-09-17) — so that case is settled by deriving **both full seeds** and comparing all 64 bytes: two PBKDF2s, on the rare path only. Never by fingerprint — 32 bits is exactly the collision this check exists to refuse. Different words are never the same secret. A value that does not parse is *not* the same secret, so it is kept: the fss9 cohort's bytes stay where they are.
  static Future<bool> _holdsSameSecret(
    String existing,
    SecretModel candidate,
    Future<Uint8List> Function(SecretModel model) seedOf,
  ) async {
    final SecretModel stored;
    try {
      stored = SecretModel.fromJson(decodeJson(existing));
    } on Exception {
      return false;
    }
    switch ((stored, candidate)) {
      case (MnemonicSecretModel a, MnemonicSecretModel b):
        if (!_sameList(a.mnemonicWords, b.mnemonicWords)) return false;
        if ((a.passphrase ?? '') == (b.passphrase ?? '')) return true;
        return _sameList(await seedOf(a), await seedOf(b));
      case (BytesSecretModel a, BytesSecretModel b):
        return _sameList(a.bytes, b.bytes);
      default:
        return false;
    }
  }

  static bool _sameList<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Reads one secret. Returns `null` only for a clean miss on the read that was allowed to settle; a last read that threw, or came back empty, propagates.
  ///
  /// The retry loop exists because two upstream failure modes produce a `null` for a key that exists (#853, #592). Believing a `null` is asymmetric — a false "present" is a benign read error, a false "absent" tells the user their wallet is gone — so a genuine miss costs the full backoff and there is no fast path for it. See the README, § Absence.
  ///
  /// [SecretStoreLockedException] passes through untouched: a sealed keystore is not an absence, and retrying cannot unseal it.
  Future<SecretModel?> fetchSecret(Fingerprint id) async {
    final json = await _readGuarded(keyForSecret(id), label: 'secret $id');
    return json == null ? null : SecretModel.fromJson(json);
  }

  /// Whether an entry exists, in a single read.
  ///
  /// Deliberately skips the retry loop [fetchSecret] runs. That loop
  /// exists because a false "absent" on a seed read tells a user their
  /// wallet is gone; here a false "absent" lets a duplicate import
  /// through, which the import flow then rejects on its own. The costs
  /// are not comparable, and ~4.5s of backoff on every import is not
  /// worth paying for the smaller one.
  Future<bool> secretExists(Fingerprint id) async =>
      await _readRaw(keyForSecret(id)) != null;

  /// Under the lock, so a delete cannot interleave with a move or a store of the same key. Never called from inside another locked operation — those use [_deleteRaw].
  Future<void> trashSecret(Fingerprint id) =>
      _lock.synchronized(() => _deleteRaw(keyForSecret(id)));

  /// Re-files the entry under [from] to the key [identify] derives from it — one read, one decision, one write, one delete, all under the lock.
  ///
  /// The identity is computed on the very model that is written, so a concurrent change to the entry cannot make this file one model under another's identity. The write refuses if [to] already holds a different secret, and the original is only deleted after the copy exists. Returns the model and where it now lives; `null` when nothing was stored under [from].
  Future<({Fingerprint id, SecretModel model})?> moveSecret(
    Fingerprint from, {
    required Future<Fingerprint> Function(SecretModel model) identify,
    required Future<Uint8List> Function(SecretModel model) seedOf,
  }) {
    final fromKey = keyForSecret(from);
    return _lock.synchronized(() async {
      // `_readRaw`, not the retry loop: a false "absent" here costs a retry of
      // the repair, never a wallet, and the lock must not be held for the
      // ~4.5 s the loop can take.
      final raw = await _readRaw(fromKey);
      if (raw == null || raw.isEmpty) return null;
      final model = SecretModel.fromJson(decodeJson(raw));
      final to = await identify(model);
      if (to == from) return (id: from, model: model);

      final toKey = keyForSecret(to);
      final existing = await _readRaw(toKey);
      if (existing != null && existing.isNotEmpty) {
        if (!await _holdsSameSecret(existing, model, seedOf)) {
          throw SecretIdentityConflict(
            'a different secret is already stored under $to',
          );
        }
      } else {
        await _writeRaw(toKey, jsonEncode(model.toJson()));
      }
      await _deleteRaw(fromKey);
      return (id: to, model: model);
    });
  }

  /// Every parsable secret in the namespace, with its identity.
  ///
  /// Unparsable entries are skipped rather than fatal: a single corrupt
  /// value must not hide the user's other wallets.
  ///
  /// One `readAll`, which on Android is all-or-nothing: an entry the
  /// plugin cannot decrypt — in any namespace, not only ours — fails the
  /// whole read. Parsing happens off the queue and off this isolate.
  Future<StoredListing> fetchAllSecrets() async {
    final entries = await _readAllRaw(secretNamespace);
    return _parseOffIsolate(entries);
  }

  /// Static so the closure below is built where `this` is not in scope.
  ///
  /// A closure created inside an instance method captures `this` even
  /// when its body never touches it — and `this` holds the queue's
  /// `Future`, which no isolate will accept. Built here, there is
  /// nothing to capture but [entries].
  static Future<StoredListing> _parseOffIsolate(Map<String, String> entries) =>
      Isolate.run(() => _parseAll(entries));

  // -------------------------------------------------------------- module keys

  /// The module key filed under [kind]/[package]/[name], creating one from [generateHex] on the first ask.
  ///
  /// Read and create are one locked operation because they must be atomic: unserialised, two first asks each read a miss, each generate, and the second write wins — the first caller then holds a key that opens nothing.
  ///
  /// **Only a clean `null` creates.** Anything present but unusable is a [ModuleKeyCorruptException] and the bytes are left exactly as they are: regenerating over them is the one irreversible act available here. The opposite of the seed namespace, where a bad value is skipped — there, one entry must not hide the others; here there is nothing to hide and something to lose. No retry loop either, for the same reason. See the README, § Database keys.
  ///
  /// Generation is the caller's: this type holds no randomness and no crypto, only the keyspace and the lock.
  Future<KeyModel> fetchOrCreateModuleKey({
    required KeyKind kind,
    required String package,
    required String name,
    required String Function() generateHex,
  }) {
    final key = keyForModule(kind: kind, package: package, name: name);
    // Taken once, around the whole read-modify-write. See the class doc:
    // nothing inside may take it again.
    return _lock.synchronized(() async {
      // A single `null` is not believed before the one irreversible act here
      // — generating over a key that exists. The plugin has returned null for
      // present entries (K1, Codex 2026-09-17; the seed path retries for the
      // same reason). One re-read after a pause turns a spurious miss into a
      // hit; a genuine first ask pays 300 ms once per module key.
      var existing = await _readRaw(key);
      if (existing == null) {
        await Future<void>.delayed(_initialDelay);
        existing = await _readRaw(key);
      }

      if (existing != null) {
        if (existing.isEmpty) {
          // A missing key reads as null, not "". Nothing this package
          // writes is empty, so the entry exists and its value did not
          // come back.
          throw ModuleKeyCorruptException('module key at $key is empty');
        }
        try {
          return KeyModel.fromJson(
            decodeJson(existing),
            expectedName: key,
            expectedKind: kind,
          );
        } on FormatException catch (e) {
          // `e.message` is one of `KeyModel`'s or `decodeJson`'s fixed
          // strings — none quotes stored content, and a test holds them
          // to it. `key` is composed by this class, not read from disk.
          throw ModuleKeyCorruptException('module key at $key: ${e.message}');
        }
      }

      final model = KeyModel.dek(
        name: key,
        bytesHex: generateHex(),
        createdAt: DateTime.now().toUtc(),
      );
      await _writeRaw(key, jsonEncode(model.toJson()));
      return model;
    });
  }

  /// The module key under [kind]/[package]/[name], **never creating one**.
  ///
  /// For the owner of a database that already exists: a miss here is exceptional, so it is concluded only after the full retry budget, and it is reported — never papered over with a fresh key that would open nothing. Same refusal as [fetchOrCreateModuleKey] for a value that is present but unusable.
  Future<KeyModel?> fetchModuleKey({
    required KeyKind kind,
    required String package,
    required String name,
  }) async {
    final key = keyForModule(kind: kind, package: package, name: name);
    // One contract for "present but unusable", whatever the shape — empty,
    // not JSON, or JSON that is not a key: [ModuleKeyCorruptException], as
    // in [fetchOrCreateModuleKey]. `_readGuarded` reports the first two as
    // `FormatException` after its retries; they are re-labelled here so the
    // caller never sees a read failure where the remedy is a corrupt-key one.
    final Map<String, dynamic>? json;
    try {
      json = await _readGuarded(key, label: 'module key $key');
    } on FormatException catch (e) {
      throw ModuleKeyCorruptException('module key at $key: ${e.message}');
    }
    if (json == null) return null;
    try {
      return KeyModel.fromJson(json, expectedName: key, expectedKind: kind);
    } on FormatException catch (e) {
      throw ModuleKeyCorruptException('module key at $key: ${e.message}');
    }
  }

  /// Removes a module key. Under the lock, so it cannot interleave with a read-or-create of the same key.
  Future<void> deleteModuleKey({
    required KeyKind kind,
    required String package,
    required String name,
  }) {
    final key = keyForModule(kind: kind, package: package, name: name);
    return _lock.synchronized(() => _deleteRaw(key));
  }

  // ------------------------------------------------------------- shared core

  /// Reads through the retry loop, for values whose absence must be
  /// trustworthy. See [fetchSecret] for why.
  Future<Map<String, dynamic>?> _readGuarded(
    String key, {
    required String label,
  }) async {
    Object? lastError;
    StackTrace? lastTrace;
    var lastWasEmpty = false;

    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      String? value;
      try {
        value = await _readRaw(key);
        lastError = null;
      } on SecretStoreLockedException {
        // Retrying cannot help: the lock clears on user unlock, not on backoff. Let the typed exception reach the UI.
        rethrow;
      } on Exception catch (e, st) {
        // `Exception` only: the loop exists to outlive a transient plugin failure, not to hide a programmer error. An `Error` propagates at once (AGENTS.md, rule 11).
        lastError = e;
        lastTrace = st;
        log.fine(
          'Error reading $label on attempt ${attempt + 1}: '
          '${describeSafely(e)}',
        );
      }
      lastWasEmpty = value != null && value.isEmpty;

      // Empty is the other face of the false-absent bug — the plugin has
      // been seen returning "" for an entry that exists — and is retried
      // exactly like null. Only a non-empty value is a value.
      if (value != null && value.isNotEmpty) {
        if (attempt > 0) {
          // Deliberately louder than the rest of this loop. This line is
          // the evidence that decides whether the loop still earns its
          // ~4.5s: if it never appears in the field, the loop goes.
          log.warning('RETRY_RESCUE: $label read on attempt ${attempt + 1}');
        }
        // Decoding is outside the retry on purpose. A value that is
        // present but is not JSON will not become JSON on the next read,
        // and it must not be reported as an absence either: the
        // exception propagates, and the façade reports a read failure —
        // never a not-found, which callers treat as "the seed is gone".
        return decodeJson(value);
      }

      if (attempt == _maxRetries - 1) break;
      await Future<void>.delayed(_initialDelay * (1 << attempt));
    }

    if (lastError != null && lastTrace != null) {
      // The last read threw. That is not a read that found nothing:
      // absence is concluded from a clean null only, and a keystore that
      // keeps failing is reported as a read failure, never as a missing
      // seed. Earlier failures followed by a clean null still count as
      // absence — the read that was allowed to settle came back empty.
      log.severe(
        message: 'Failed to read $label after $_maxRetries attempts',
        error: describeSafely(lastError),
        trace: lastTrace,
      );
      Error.throwWithStackTrace(lastError, lastTrace);
    }
    if (lastWasEmpty) {
      // The key is there — a missing key reads as null, not "" — but its
      // value never came. Nothing this package writes is empty, so this
      // is an entry that cannot be read, and it is reported as such.
      throw const FormatException('stored value is empty');
    }

    return null;
  }

  /// Decodes a stored value, or throws [FormatException].
  ///
  /// Folds the two ways a value can fail to be one of ours — not JSON,
  /// or JSON of the wrong shape — into one exception type, with a fixed
  /// message. `jsonDecode`'s own [FormatException] quotes its source in
  /// `toString`, and the source here is the stored secret.
  static Map<String, dynamic> decodeJson(String value) {
    final Object? decoded;
    try {
      decoded = jsonDecode(value);
    } on FormatException {
      throw const FormatException('stored value is not JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('stored value is not a JSON object');
    }
    return decoded;
  }

  // -------------------------------------------------------------------- lock

  /// Guards composed operations — [storeSecret], [moveSecret], [trashSecret], [fetchOrCreateModuleKey], [deleteModuleKey].
  /// Process-wide, because the keystore is. See the class doc for why it
  /// is not per instance, why single calls are not guarded, and why it
  /// must never be taken twice on one path.
  static final _lock = Lock();

  // -------------------------------------------------------------- primitives

  /// Never takes [_lock]. A composed operation already holds it, and
  /// `Lock` is not reentrant: taking it here would hang, not throw.
  Future<String?> _readRaw(String key) =>
      _translate(() => _storage.read(key: key));

  Future<void> _writeRaw(String key, String value) =>
      _translate(() => _storage.write(key: key, value: value));

  Future<void> _deleteRaw(String key) =>
      _translate(() => _storage.delete(key: key));

  Future<Map<String, String>> _readAllRaw(String prefix) async {
    final all = await _translate(_storage.readAll);
    return {
      for (final e in all.entries)
        if (e.key.startsWith(prefix)) e.key: e.value,
    };
  }

  Future<T> _translate<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PlatformException catch (e) {
      if (e.details == _errSecInteractionNotAllowed ||
          e.code == '$_errSecInteractionNotAllowed' ||
          (e.message ?? '').contains('$_errSecInteractionNotAllowed')) {
        throw const SecretStoreLockedException(
          'device has not been unlocked since boot',
        );
      }
      rethrow;
    }
  }
}

/// Parsing for [FlutterSecureStorageDatasource.fetchAllSecrets], off the
/// isolate.
///
/// Top-level, and reached through a static method, because a closure
/// created inside an instance method captures `this` even when its body
/// does not use it — and `this` holds the queue's `Future`, which is
/// unsendable, so `Isolate.run` fails on every listing.
StoredListing _parseAll(Map<String, String> entries) {
  const namespace = FlutterSecureStorageDatasource.secretNamespace;
  final secrets = <StoredSecret>[];
  var unparsable = 0;
  for (final entry in entries.entries) {
    if (!entry.key.startsWith(namespace)) continue;
    // Under this package's prefix but not something it wrote — an empty
    // value, a key that is not a fingerprint, a value that is not our JSON.
    // Skipped, so it cannot hide the others; counted, so it is not hidden
    // itself.
    final id = FlutterSecureStorageDatasource.idFromKey(entry.key);
    if (entry.value.isEmpty || id == null) {
      unparsable++;
      continue;
    }
    try {
      secrets.add((
        id: id,
        model: SecretModel.fromJson(
          FlutterSecureStorageDatasource.decodeJson(entry.value),
        ),
      ));
    } on Exception {
      // A value that does not parse is skipped, not a listing failure. An `Error` propagates.
      unparsable++;
    }
  }
  return (parsed: secrets, unparsable: unparsable);
}

/// The platform keystore is sealed and the value cannot be read *right now*.
///
/// Distinct from "no such secret" on purpose. iOS returns
/// `errSecInteractionNotAllowed` (-25308) when the device has not been
/// unlocked since boot and the item's accessibility class requires
/// post-unlock access. Retrying cannot help — only a user unlock clears
/// it — and collapsing it into a not-found makes callers such as
/// `CheckForExistingDefaultWalletsUsecase` read a transient,
/// self-healing state as "the wallet seed is gone" and offer destructive
/// recovery.
