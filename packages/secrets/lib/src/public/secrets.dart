import 'dart:async';

import 'package:bip39_mnemonic/bip39_mnemonic.dart'
    show Language, MnemonicLength;
import 'package:bull_logger/bull_logger.dart';
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

  /// Opens the store the user's secrets live in.
  ///
  /// The host supplies nothing about storage: the package builds its own `flutter_secure_storage` and hands one out to nobody. Reaching the seeds from outside means constructing the plugin yourself and hardcoding the prefix — visible in review, rather than a call on an object you were given.
  ///
  /// [scratchDirectory] is a directory lwk may use as a cache while signing, since `Wallet.init` has no in-memory persister. Bitcoin signing writes nothing. It disappears the day lwk-dart binds its signer directly.
  ///
  /// Tests substitute the store below this type, at `FlutterSecureStoragePlatform.instance`.
  factory Secrets({required Future<String> Function() scratchDirectory}) {
    // A signature the process did not survive leaves its lwk cache behind;
    // sweep it now rather than at the next Liquid signature, which may never
    // come. Same age rule as the pre-signature sweep, so a second `Secrets`
    // in another isolate cannot take a signature still in flight.
    unawaited(Signer.liquid.sweepScratch(scratchDirectory));
    return Secrets._(DatabaseKeyRepository(), scratchDirectory);
  }

  Secrets._(this._databaseKeys, this._scratchDirectory);

  /// Every keystore key prefix this package owns.
  ///
  /// The app shares one OS keystore with this package, so its own store
  /// must refuse these — a shared store that could read `seed_…` would
  /// hand seed material to code that only meant to read a preference.
  /// Published so the refusal is written against the package's own
  /// strings and cannot drift from them.
  static const reservedKeyPrefixes = {
    FlutterSecureStorageDatasource.secretNamespace,
    FlutterSecureStorageDatasource.keyNamespace,
  };

  /// Checks Android's physical store before any plugin initialization. A null result permits normal startup; a list requires the terminal backup screen. Failure never authorizes a fresh install or a write to the old store.
  static Future<Result<List<Secret>?, SecretFailure>> legacyBackup({
    required Future<String> Function() scratchDirectory,
  }) => boundary(() async {
    if (await FlutterSecureStorageDatasource.normalStoreAvailable()) {
      return null;
    }
    final repository = SecretRepository(legacyReadOnly: true);
    final listing = await repository.describeAll();
    final infos = switch (listing) {
      Ok(:final value)
          when value.unreadable.isEmpty && value.secrets.isNotEmpty =>
        value.secrets,
      _ => throw const FormatException('legacy backup unavailable'),
    };
    final handles = <Secret>[];
    for (final info in infos) {
      // CBC has no authentication: validate BIP39, shape and derived fingerprint before offering any backup. Seed-only entries cannot be backed up here.
      if (!info.isMnemonic) {
        throw const FormatException('legacy backup unavailable');
      }
      final checked = await repository.use(info, (material) {
        material.seedBytes.fillRange(0, material.seedBytes.length, 0);
      });
      if (checked is Err) {
        throw const FormatException('legacy backup unavailable');
      }
      handles.add(
        Secret(
          info,
          repository: repository,
          scratchDirectory: scratchDirectory,
        ),
      );
    }
    return List<Secret>.unmodifiable(handles);
  }, orElse: FetchSecretFailure.new);

  // ---------------------------------------------------------------- creation

  /// Generates a fresh mnemonic, stores it, returns its handle.
  @useResult
  Future<Result<Secret, SecretFailure>> generate({
    MnemonicLength wordCount = MnemonicLength.words12,
  }) async => (await _repository.store(
    words: Generator.mnemonic(wordCount: wordCount),
    rejectExisting: true,
  )).map(_handle);

  /// Imports user-supplied words and returns a newly stored secret. The caller must release its input afterwards. Invalid words return [InvalidMnemonicFailure]; an existing secret returns [SecretAlreadyExistsFailure] without changing storage.
  ///
  /// With [acceptOnly], words that derive to any other fingerprint return [FingerprintMismatchFailure] and nothing is written.
  @useResult
  Future<Result<Secret, SecretFailure>> import({
    required List<String> words,
    Language language = Language.english,
    String? passphrase,
    Set<Fingerprint>? acceptOnly,
  }) async => (await _repository.store(
    words: words,
    language: language,
    passphrase: passphrase,
    rejectExisting: true,
    acceptOnly: acceptOnly,
  )).map(_handle);

  // ----------------------------------------------------------------- queries

  /// Finds one stored secret.
  ///
  /// Validates the stored shape without deriving a seed. A stored value that is not a secret is a [FetchSecretFailure], never a [SecretNotFoundFailure].
  @useResult
  Future<Result<Secret, SecretFailure>> fetch(Fingerprint id) async =>
      (await _repository.describe(id)).map(_handle);

  /// Every stored entry: a usable [Secret] or an [UnreadableSecret] with its failure and, when recoverable, its fingerprint.
  ///
  /// Cheap: a [Secret] is a description plus a shared reference, so an item you just listed can act without a second round-trip.
  ///
  /// Reads the keystore with one `readAll`, which on Android is all-or-nothing: an entry the plugin cannot decrypt — in *any* namespace — fails the whole read. A failed listing therefore says nothing about any particular seed and must not be read as one being gone. [fetch] reads one key and is unaffected.
  @useResult
  Future<Result<List<SecretEntry>, SecretFailure>> list() async =>
      (await _repository.describeAll()).map(
        (listing) => List<SecretEntry>.unmodifiable([
          ...listing.secrets.map(_handle),
          for (final entry in listing.unreadable)
            UnreadableSecret(id: entry.id, failure: entry.failure),
        ]),
      );

  /// Unconditional delete.
  ///
  /// The "refuse to delete a secret that still backs a wallet" guard
  /// stays with the caller: it needs to know what a wallet is, and this
  /// package deliberately does not.
  @useResult
  Future<Result<void, SecretFailure>> trash(Fingerprint id) =>
      _repository.trash(id);

  /// Whether a secret is already stored under [id].
  ///
  /// Best-effort and fast, unlike [fetch]: it does not run the retry
  /// loop that a seed read does. Use it only for indicative checks, never to conclude that a wallet's seed has disappeared. [import] checks duplicates atomically.
  @useResult
  Future<Result<bool, SecretFailure>> exists(Fingerprint id) =>
      _repository.exists(id);

  /// Whether these words and passphrase are already stored, comparing full seed bytes. Invalid words return [InvalidMnemonicFailure]; keystore failures remain failures. This preflight does not reserve an import.
  @useResult
  Future<Result<bool, SecretFailure>> contains({
    required List<String> words,
    Language language = Language.english,
    String? passphrase,
  }) => _repository.contains(
    words: words,
    language: language,
    passphrase: passphrase,
  );

  // ----------------------------------------------------------------- preview

  /// Public derivations from words that are not stored, such as a scan before import.
  SecretPreview get preview => SecretPreview._(this);

  /// External and internal public descriptors of account 0 for words that are not stored, in [language] and with [passphrase], keyed by each of [scriptTypes].
  ///
  /// Stateless: the keystore is neither read nor written, and the seed is derived once for every script type, used and wiped in a separate isolate. Only public descriptor strings leave it. Invalid words return [InvalidMnemonicFailure]. For English words they equal those of the same words once imported (`secret.derive.descriptors.bitcoin`); `import` accepts English only for now.
  @internal
  @useResult
  Future<Result<Map<ScriptType, Descriptors>, SecretFailure>>
  previewBitcoinDescriptors({
    required List<String> words,
    Language language = Language.english,
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

  // ----------------------------------------------------------------- restore

  /// RecoverBull vault restoration and stateless backup verification.
  Recoverbull get recoverbull => Recoverbull._(this);

  /// Opens a RecoverBull vault and stores its words, returning a handle and the caller's metadata.
  ///
  /// Decryption and import stay inside the package. An invalid vault or wrong key returns [InvalidVaultFailure] without storing a secret.
  ///
  /// The vault contains no passphrase. Supply [passphrase] separately to restore a passphrase-protected Bitcoin wallet. The vault cannot verify that passphrase; the app's default wallets always restore without one.
  @internal
  @useResult
  Future<Result<RestoredVault, SecretFailure>> restoreRecoverbull({
    required EncryptedVault vault,
    required VaultKey key,
    String? passphrase,
  }) async =>
      (await _repository.restore(
        file: vault.json,
        key: key.hex,
        passphrase: passphrase,
      )).map((restored) {
        log.fine('secret.backup.restored');
        return (secret: _handle(restored.info), metadata: restored.metadata);
      });

  /// Opens a vault and derives the fingerprint of its words without reading or writing the keystore.
  ///
  /// The fingerprint is computed with no passphrase and never trusted from the vault's metadata. Use this to check a backup without importing or replacing any stored secret.
  @internal
  @useResult
  Future<Result<Fingerprint, SecretFailure>> inspectRecoverbull({
    required EncryptedVault vault,
    required VaultKey key,
  }) => _repository.inspect(file: vault.json, key: key.hex);

  // ----------------------------------------------------------- database keys

  /// Access to one module's database keys. Pass this handle to the module instead of the entire [Secrets] service.
  ///
  /// The module name is fixed in the handle; each operation names only a database within that module. Changing this API does not change the persisted key namespace.
  DatabaseKeys databaseKeys({required String module}) {
    _requireKeySegment(module, 'module');
    return DatabaseKeys._(_databaseKeys, module);
  }

  Secret _handle(SecretInfo info) => Secret(
    info,
    repository: _repository,
    scratchDirectory: _scratchDirectory,
  );
}

/// What a restored vault gives back: the secret, and the caller's own
/// fields — never the words. Callers remain responsible for the sensitivity of their own metadata.
typedef RestoredVault = ({Secret secret, Map<String, dynamic> metadata});

/// Vault operations that do not require an existing stored secret.
extension type const Recoverbull._(Secrets _secrets) {
  /// Decrypts a vault and stores its words. Repeated restoration is idempotent.
  /// The vault has no passphrase; supply one separately if the original wallet used it.
  @useResult
  Future<Result<RestoredVault, SecretFailure>> restore({
    required EncryptedVault vault,
    required VaultKey key,
    String? passphrase,
  }) => _secrets.restoreRecoverbull(
    vault: vault,
    key: key,
    passphrase: passphrase,
  );

  /// Derives the words-only fingerprint without reading or writing the keystore.
  @useResult
  Future<Result<Fingerprint, SecretFailure>> fingerprint({
    required EncryptedVault vault,
    required VaultKey key,
  }) => _secrets.inspectRecoverbull(vault: vault, key: key);
}

/// Public derivations from words that are not stored. Nothing is written and no material is returned.
extension type const SecretPreview._(Secrets _secrets) {
  /// Public Bitcoin descriptors of account 0 for unstored words, one pair per script type. See [Secrets.previewBitcoinDescriptors].
  @useResult
  Future<Result<Map<ScriptType, Descriptors>, SecretFailure>>
  bitcoinDescriptors({
    required List<String> words,
    Language language = Language.english,
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
}

/// Database encryption keys scoped to one module.
final class DatabaseKeys {
  final DatabaseKeyRepository _repository;
  final String _module;

  DatabaseKeys._(this._repository, this._module);

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

void _requireKeySegment(String segment, String label) {
  if (segment.isEmpty || segment.contains('/')) {
    throw ArgumentError.value(
      segment,
      label,
      'must be non-empty and free of "/"',
    );
  }
}
