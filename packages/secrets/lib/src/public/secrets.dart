import 'dart:async';
import 'dart:io';

import 'package:secrets/src/public/keychains.dart';

import 'package:bip39_mnemonic/bip39_mnemonic.dart'
    show Language, MnemonicLength;
import 'package:bull_logger/bull_logger.dart';
import 'package:drift/drift.dart' show QueryExecutor;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/crypto.dart';
import 'package:secrets/src/data/data.dart';
import 'package:secrets/src/domain/domain.dart';
import 'package:secrets/src/public/secret.dart';

/// The only door into stored key material.
///
/// This class is the lifecycle: make a secret, find one, forget one.
/// Everything you can *do* with a secret lives on the [Secret] it hands
/// back, grouped by what the operation does to it:
///
/// ```dart
/// final secret = switch (await secrets.fetch(Fingerprint(fingerprint))) {
///   Ok(:final value) => value,
///   Err(:final failure) => return failure,
/// };
///
/// await secret.derive.xpub(network: …, scriptType: …);
/// await secret.sign.psbt(psbt, network: …, scriptType: …);
/// ```
///
/// Query with a [Fingerprint], operate with a [Secret]. Queries are cheap:
/// they read the keystore and project metadata, deriving nothing.
final class Secrets {
  final _repository = SecretRepository();
  final DatabaseKeyRepository _databaseKeys;
  final Future<String> Function() _scratchDirectory;
  final SessionAuthority _authority;

  /// Opens the store the user's secrets live in.
  ///
  /// The host supplies nothing about storage: the package builds its own `flutter_secure_storage` and hands one out to nobody. Reaching the seeds from outside means constructing the plugin yourself and hardcoding the prefix — visible in review, rather than a call on an object you were given.
  ///
  /// [scratchDirectory] is a directory lwk may use as a cache while signing, since `Wallet.init` has no in-memory persister. Bitcoin signing writes nothing. It disappears the day lwk-dart binds its signer directly.
  ///
  /// Tests substitute the store below this type, at `FlutterSecureStoragePlatform.instance`.
  ///
  /// [authority] is the session shared with the inventory. There is no `Secrets` without one: while it is locked every operation on stored secrets is refused, and a handle stops working when the session it was issued in ends. Database keys and the closed owner keychains do not depend on a session (D63).
  factory Secrets({
    required Future<String> Function() scratchDirectory,
    required SessionAuthority authority,
  }) {
    // A signature the process did not survive leaves its lwk cache behind;
    // sweep it now rather than at the next Liquid signature, which may never
    // come. Same age rule as the pre-signature sweep, so a second `Secrets`
    // in another isolate cannot take a signature still in flight.
    unawaited(Signer.liquid.sweepScratch(scratchDirectory));
    return Secrets._(DatabaseKeyRepository(), scratchDirectory, authority);
  }

  Secrets._(this._databaseKeys, this._scratchDirectory, this._authority);

  /// Seed and database-key namespaces, kept for callers auditing legacy data.
  /// Owner-scoped keychains use a separate closed set of historical keys.
  static const reservedKeyPrefixes = {
    FlutterSecureStorageDatasource.secretNamespace,
    FlutterSecureStorageDatasource.keyNamespace,
  };

  /// Closed owner-scoped capabilities over unchanged legacy keychain entries.
  SilentPaymentKeychain get silentPaymentKeychain => SilentPaymentKeychain();
  SwapKeychain get swapKeychain => SwapKeychain();

  // ---------------------------------------------------------------- creation

  /// Generates a fresh mnemonic, stores it, returns its handle.
  @useResult
  Future<Result<Secret, SecretFailure>> generate({
    MnemonicLength wordCount = MnemonicLength.words12,
  }) => _write(
    (scope) async => (await _repository.store(
      words: Generator.mnemonic(wordCount: wordCount),
      // bdk generates English words.
      language: Language.english,
      rejectExisting: true,
    )).map((info) => _handle(info, scope, made: true)),
  );

  /// Imports user-supplied words and returns a newly stored secret. The caller must release its input afterwards. Invalid words return [InvalidMnemonicFailure]; an existing secret returns [SecretAlreadyExistsFailure] without changing storage.
  ///
  /// With [acceptOnly], words that derive to any other fingerprint return [FingerprintMismatchFailure] and nothing is written.
  @useResult
  Future<Result<Secret, SecretFailure>> import({
    required List<String> words,
    required Language language,
    String? passphrase,
    Set<Fingerprint>? acceptOnly,
  }) => _write(
    (scope) async => (await _repository.store(
      words: words,
      language: language,
      passphrase: passphrase,
      rejectExisting: true,
      acceptOnly: acceptOnly,
    )).map((info) => _handle(info, scope, made: true)),
  );

  // ----------------------------------------------------------------- queries

  /// Finds one stored secret.
  ///
  /// Validates the stored shape without deriving a seed. A stored value that is not a secret is a [FetchSecretFailure], never a [SecretNotFoundFailure].
  @useResult
  Future<Result<Secret, SecretFailure>> fetch(Fingerprint id) =>
      _read((scope) async {
        if (!await _authority.mayUse(scope.token, id)) {
          return const Err(secretNotInViewFailure);
        }
        return (await _repository.describe(id))
            .map((info) => _handle(info, scope));
      });

  /// Every stored entry: a usable [Secret] or an [UnreadableSecret] with its failure and, when recoverable, its fingerprint.
  ///
  /// Cheap: a [Secret] is a description plus a shared reference, so an item you just listed can act without a second round-trip.
  ///
  /// Reads the keystore with one `readAll`, which on Android is all-or-nothing: an entry the plugin cannot decrypt — in *any* namespace — fails the whole read. A failed listing therefore says nothing about any particular seed and must not be read as one being gone. [fetch] reads one key and is unaffected.
  @useResult
  Future<Result<List<SecretEntry>, SecretFailure>> list() =>
      _read((scope) async {
        final visible = await _authority.visibleTo(scope.token);
        return (await _repository.describeAll()).map(
          (listing) => List<SecretEntry>.unmodifiable([
            for (final info in listing.secrets)
              if (visible == null || visible.contains(info.id.hex))
                _handle(info, scope),
            for (final entry in listing.unreadable)
              // An entry whose seed cannot be named cannot be placed in a view.
              if (visible == null ||
                  (entry.id != null && visible.contains(entry.id!.hex)))
                UnreadableSecret(id: entry.id, failure: entry.failure),
          ]),
        );
      });

  /// Unconditional delete.
  ///
  /// The "refuse to delete a secret that still backs a wallet" guard
  /// stays with the caller: it needs to know what a wallet is, and this
  /// package deliberately does not.
  @useResult
  Future<Result<void, SecretFailure>> trash(Fingerprint id) =>
      _write((scope) async {
        if (!await _authority.mayUse(scope.token, id)) {
          return const Err(secretNotInViewFailure);
        }
        return _repository.trash(id);
      });

  /// Whether a secret is already stored under [id].
  ///
  /// Best-effort and fast, unlike [fetch]: it does not run the retry
  /// loop that a seed read does. Use it only for indicative checks, never to conclude that a wallet's seed has disappeared. [import] checks duplicates atomically.
  @useResult
  Future<Result<bool, SecretFailure>> exists(Fingerprint id) =>
      _read((scope) async {
        if (!await _authority.mayUse(scope.token, id)) return const Ok(false);
        return _repository.exists(id);
      });

  /// Whether these words and passphrase are already stored, comparing full seed bytes. Invalid words return [InvalidMnemonicFailure]; keystore failures remain failures. This preflight does not reserve an import.
  @useResult
  Future<Result<bool, SecretFailure>> contains({
    required List<String> words,
    required Language language,
    String? passphrase,
  }) async => (await find(
    words: words,
    language: language,
    passphrase: passphrase,
  )).map((secret) => secret != null);

  /// Finds an existing secret by full seed equality, including its passphrase.
  /// Does not write storage. Absence is null; unreadable custody remains Err.
  @useResult
  Future<Result<Secret?, SecretFailure>> find({
    required List<String> words,
    required Language language,
    String? passphrase,
  }) => _read(
    (scope) async => (await _repository.find(
      words: words,
      language: language,
      passphrase: passphrase,
    )).map((info) => info == null ? null : _handle(info, scope, made: true)),
  );

  // ----------------------------------------------------------------- preview

  /// Public derivations from words that are not stored, such as a scan before import.
  SecretPreview get preview => SecretPreview._(this);

  /// Bark m/350h identity of an already scoped child, without storage access.
  @internal
  @useResult
  Future<Result<Fingerprint, SecretFailure>> previewArkFingerprint({
    required List<String> words,
  }) => _repository.previewArkFingerprint(words: words);

  /// External and internal public descriptors of account 0 for words that are not stored, in [language] and with [passphrase], keyed by each of [scriptTypes].
  ///
  /// Stateless: the keystore is neither read nor written, and the seed is derived once for every script type, used and wiped in a separate isolate. Only public descriptor strings leave it. Invalid words return [InvalidMnemonicFailure]. They equal those of the same words once imported in the same language (`secret.derive.descriptors.bitcoin`).
  @internal
  @useResult
  Future<Result<Map<ScriptType, Descriptors>, SecretFailure>>
  previewBitcoinDescriptors({
    required List<String> words,
    required Language language,
    String? passphrase,
    required BitcoinNetwork network,
    required Set<ScriptType> scriptTypes,
  }) => _repository.previewBitcoinDescriptors(
    words: words,
    language: language,
    passphrase: passphrase,
    network: network,
    scriptTypes: scriptTypes,
  );

  /// Compares both full public descriptors after BDK canonicalization. Invalid
  /// expected descriptors or checksums do not match. No keystore is accessed.
  @internal
  @useResult
  Future<Result<bool, SecretFailure>> matchesBitcoinDescriptors({
    required List<String> words,
    required Language language,
    String? passphrase,
    required BitcoinNetwork network,
    required ScriptType scriptType,
    required Descriptors expected,
  }) async =>
      (await previewBitcoinDescriptors(
        words: words,
        language: language,
        passphrase: passphrase,
        network: network,
        scriptTypes: {scriptType},
      )).map((descriptors) {
        final actual = descriptors[scriptType];
        return actual != null &&
            Deriver.bitcoin.matchesPublicDescriptors(
              actual: actual,
              expected: expected,
              network: network,
            );
      });

  // ----------------------------------------------------------------- restore

  /// RecoverBull vault restoration and stateless backup verification.
  Recoverbull get recoverbull => Recoverbull._(this);

  /// Opens a RecoverBull vault and stores its words, returning a handle and the caller's metadata.
  ///
  /// Decryption and import stay inside the package. An invalid vault or wrong key returns [InvalidVaultFailure] without storing a secret.
  ///
  /// The vault contains no passphrase. Supply it separately. The candidate must reproduce the vault key at its recorded path before any write. [allowUnverified] permits only the empty-passphrase sibling after an explicit user decision; it does not certify the backup.
  @internal
  @useResult
  Future<Result<RestoredVault, SecretFailure>> restoreRecoverbull({
    required EncryptedVault vault,
    required VaultKey key,
    String? passphrase,
    bool allowUnverified = false,
  }) => _write(
    (scope) async =>
        (await _repository.restore(
          file: vault.json,
          key: key.hex,
          passphrase: passphrase,
          allowUnverified: allowUnverified,
        )).map((restored) {
          log.fine('secret.backup.restored');
          return (
            secret: _handle(restored.info, scope, made: true),
            metadata: restored.metadata,
          );
        }),
  );

  /// Opens a vault and derives the fingerprint of its words without reading or writing the keystore.
  ///
  /// The candidate must reproduce the vault key; metadata never supplies the fingerprint. No secret is imported or replaced.
  @internal
  @useResult
  Future<Result<Fingerprint, SecretFailure>> inspectRecoverbull({
    required EncryptedVault vault,
    required VaultKey key,
    String? passphrase,
  }) => _repository.inspect(
    file: vault.json,
    key: key.hex,
    passphrase: passphrase,
  );

  // ----------------------------------------------------------- database keys

  /// Access to one module's database keys. Pass this handle to the module instead of the entire [Secrets] service.
  ///
  /// The module name is fixed in the handle; each operation names only a database within that module. Changing this API does not change the persisted key namespace.
  DatabaseKeys databaseKeys({required String module}) {
    _requireDatabaseModule(module);
    return DatabaseKeys._(_databaseKeys, module);
  }

  /// Captures the Flutter keystore bridge on the root isolate and returns a
  /// factory of worker-only openers. Only scoped names and the file path are
  /// sent to the worker, never the Secrets instance, a key, or a connection.
  /// A worker opening an existing owner still needs to verify its readiness.
  static Future<Result<QueryExecutor, F>> Function() Function(bool existing)
  databaseOpener<F extends Failure>({
    required String module,
    required String name,
    required File file,
    required int schema,
    required F deferred,
    required F unavailable,
  }) {
    _requireDatabaseModule(module);
    _requireKeySegment(name, 'name');
    if (schema < 1) throw ArgumentError.value(schema, 'schema');
    return captureDatabaseWorkerOpener(
      module: module,
      name: name,
      path: file.path,
      schema: schema,
      deferred: deferred,
      unavailable: unavailable,
    );
  }

  /// Reads: refused while locked, and a result that finishes after the session ended is not delivered.
  Future<Result<T, SecretFailure>> _read<T>(
    Future<Result<T, SecretFailure>> Function(SessionScope scope) run,
  ) async {
    final scope = _enter();
    if (scope == null) return const Err(inventoryLockedFailure);
    final result = await run(scope);
    return scope.isCurrent ? result : const Err(inventorySessionChangedFailure);
  }

  /// Writes: refused while locked. Work already committed reports its true result; a handle it returns belongs to the session it started in.
  Future<Result<T, SecretFailure>> _write<T>(
    Future<Result<T, SecretFailure>> Function(SessionScope scope) run,
  ) async {
    final scope = _enter();
    if (scope == null) return const Err(inventoryLockedFailure);
    return run(scope);
  }

  SessionScope? _enter() {
    final token = _authority.current;
    return token == null ? null : SessionScope(_authority, token);
  }

  Secret _handle(SecretInfo info, SessionScope scope, {bool made = false}) {
    if (made) _authority.noteMade(scope.token, info.id);
    return Secret(
      info,
      repository: _repository,
      scope: scope,
      scratchDirectory: _scratchDirectory,
    );
  }
}

/// What a restored vault gives back: the secret, and the caller's own
/// fields — never the words. Callers remain responsible for the sensitivity of their own metadata.
typedef RestoredVault = ({Secret secret, Map<String, dynamic> metadata});

/// Vault operations that do not require an existing stored secret.
extension type const Recoverbull._(Secrets _secrets) {
  /// Decrypts a vault and stores its words. Repeated restoration is idempotent.
  /// The vault has no passphrase; supply one separately if the original wallet used it. An unverified empty-passphrase sibling requires explicit opt-in.
  @useResult
  Future<Result<RestoredVault, SecretFailure>> restore({
    required EncryptedVault vault,
    required VaultKey key,
    String? passphrase,
    bool allowUnverified = false,
  }) => _secrets.restoreRecoverbull(
    vault: vault,
    key: key,
    passphrase: passphrase,
    allowUnverified: allowUnverified,
  );

  /// Verifies the supplied passphrase against the vault key without accessing the keystore.
  @useResult
  Future<Result<Fingerprint, SecretFailure>> fingerprint({
    required EncryptedVault vault,
    required VaultKey key,
    String? passphrase,
  }) => _secrets.inspectRecoverbull(
    vault: vault,
    key: key,
    passphrase: passphrase,
  );
}

/// Public derivations from words that are not stored. Nothing is written and no material is returned.
extension type const SecretPreview._(Secrets _secrets) {
  /// Public consistency identity of an already scoped Ark child at m/350h. English and the empty passphrase preserve existing Bark identities.
  ///
  /// This 32-bit discriminator is not cryptographic authentication. No keystore is accessed; invalid words return a typed failure without exposing them.
  @useResult
  Future<Result<Fingerprint, SecretFailure>> arkFingerprint({
    required List<String> words,
  }) => _secrets.previewArkFingerprint(words: words);

  /// Public Bitcoin descriptors of account 0 for unstored words, one pair per script type. See [Secrets.previewBitcoinDescriptors].
  @useResult
  Future<Result<Map<ScriptType, Descriptors>, SecretFailure>>
  bitcoinDescriptors({
    required List<String> words,
    required Language language,
    String? passphrase,
    required BitcoinNetwork network,
    required Set<ScriptType> scriptTypes,
  }) => _secrets.previewBitcoinDescriptors(
    words: words,
    language: language,
    passphrase: passphrase,
    network: network,
    scriptTypes: scriptTypes,
  );

  /// Compares full public descriptors without accessing the keystore.
  @useResult
  Future<Result<bool, SecretFailure>> matchesBitcoinDescriptors({
    required List<String> words,
    required Language language,
    String? passphrase,
    required BitcoinNetwork network,
    required ScriptType scriptType,
    required Descriptors expected,
  }) => _secrets.matchesBitcoinDescriptors(
    words: words,
    language: language,
    passphrase: passphrase,
    network: network,
    scriptType: scriptType,
    expected: expected,
  );
}

/// Database encryption keys scoped to one module.
final class DatabaseKeys {
  final DatabaseKeyRepository _repository;
  final String _module;

  DatabaseKeys._(this._repository, this._module);

  /// Keys one native connection and transfers its ownership to Drift.
  ///
  /// Supplying [existingSchemaVersion] makes the open background-only:
  /// the database must exist at that version and Drift migrations are disabled.
  /// The owner must still check its import receipt before exposing the connection.
  /// Foreground creation and resets require exclusive owner coordination.
  @useResult
  Future<Result<QueryExecutor, DatabaseOpenFailure>> open({
    required String name,
    required File file,
    int? existingSchemaVersion,
  }) {
    _requireKeySegment(name, 'name');
    if (existingSchemaVersion != null && existingSchemaVersion < 1) {
      throw ArgumentError.value(existingSchemaVersion, 'existingSchemaVersion');
    }
    return openEncryptedDatabase(
      _repository,
      module: _module,
      name: name,
      file: file,
      existingSchemaVersion: existingSchemaVersion,
    );
  }

  /// Gets an existing key or atomically creates one. A corrupt stored key is refused, never overwritten.
  @useResult
  Future<Result<DatabaseKey, SecretFailure>> getOrCreate({
    required String name,
  }) async {
    _requireKeySegment(name, 'name');
    return _repository.forModule(module: _module, name: name);
  }

  /// Gets an existing key without creating one. Absence remains [SecretNotFoundFailure].
  @useResult
  Future<Result<DatabaseKey, SecretFailure>> get({required String name}) async {
    _requireKeySegment(name, 'name');
    return _repository.existing(module: _module, name: name);
  }

  /// Deletes a key. Its owner must also discard the database it encrypted; recovery never calls this automatically.
  @useResult
  Future<Result<void, SecretFailure>> reset({required String name}) async {
    _requireKeySegment(name, 'name');
    return _repository.reset(module: _module, name: name);
  }
}

void _requireDatabaseModule(String module) {
  _requireKeySegment(module, 'module');
  if (module == inventoryModule) {
    throw ArgumentError('The wallet inventory does not export database keys');
  }
}

void _requireKeySegment(String segment, String label) {
  if (segment.isEmpty || segment.contains('/')) {
    throw ArgumentError.value(
      segment,
      label,
      'must be non-empty and free of "/"',
    );
  }
}
