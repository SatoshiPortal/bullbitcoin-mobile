import 'dart:async';

import 'package:bull_logger/bull_logger.dart';
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

  // ---------------------------------------------------------------- creation

  /// Generates a fresh mnemonic, stores it, returns its handle.
  Future<Result<Secret, SecretFailure>> generate({
    MnemonicWordCount wordCount = MnemonicWordCount.words12,
  }) async => (await _repository.store(
    words: Generator.mnemonic(wordCount: wordCount),
  )).map(_handle);

  /// Imports user-supplied words. The words are consumed here and never
  /// held by the caller afterwards. Words that are not a BIP39 mnemonic
  /// are an [InvalidMnemonicFailure]; nothing is stored.
  Future<Result<Secret, SecretFailure>> import({
    required List<String> words,
    String? passphrase,
  }) async => (await _repository.store(
    words: words,
    passphrase: passphrase,
  )).map(_handle);

  // ----------------------------------------------------------------- queries

  /// Finds one stored secret.
  ///
  /// Derives nothing unless the secret carries a passphrase, in which
  /// case its passphrase-less identity costs one PBKDF2 pass — see
  /// [SecretRepository.describe]. A stored value that is not a secret
  /// is a [SecretFetchFailure], never a [SecretNotFoundFailure].
  Future<Result<Secret, SecretFailure>> fetch(Fingerprint id) async =>
      (await _repository.describe(id)).map(_handle);

  /// Every stored secret, as handles.
  ///
  /// Cheap: a [Secret] is a description plus a shared reference, so an item you just listed can act without a second round-trip.
  ///
  /// Reads the keystore with one `readAll`, which on Android is all-or-nothing: an entry the plugin cannot decrypt — in *any* namespace — fails the whole read. A failed listing therefore says nothing about any particular seed and must not be read as one being gone. [fetch] reads one key and is unaffected.
  Future<Result<SecretListing<Secret>, SecretFailure>> list() async =>
      (await _repository.describeAll()).map((l) => l.map(_handle));

  /// Unconditional delete.
  ///
  /// The "refuse to delete a secret that still backs a wallet" guard
  /// stays with the caller: it needs to know what a wallet is, and this
  /// package deliberately does not.
  Future<Result<void, SecretFailure>> trash(Fingerprint id) =>
      _repository.trash(id);

  /// Whether a secret is already stored under [id].
  ///
  /// Best-effort and fast, unlike [fetch]: it does not run the retry
  /// loop that a seed read does. Use it for questions where a wrong
  /// "no" is cheap — the duplicate-import check is the one that matters
  /// — and never to conclude that a wallet's seed has disappeared.
  Future<Result<bool, SecretFailure>> exists(Fingerprint id) =>
      _repository.exists(id);

  /// Identity a candidate mnemonic would have, without storing it.
  ///
  /// Backs the duplicate-import check, which compares [Fingerprint]s
  /// rather than bare strings.
  ///
  /// Returns a [Result] even though it touches no keystore: the words
  /// are user input, and `bip39_mnemonic` names the offending word in
  /// its exceptions. Letting one escape would carry that word into
  /// whatever caught it.
  Future<Result<Fingerprint, SecretFailure>> idOf({
    required List<String> words,
    String? passphrase,
  }) => _repository.idOf(words: words, passphrase: passphrase);

  // ----------------------------------------------------------------- restore

  /// Opens a RecoverBull vault and stores the secret it carries.
  ///
  /// Decryption and import are one operation on purpose: splitting them would hand the caller a mnemonic so it could hand it back, on the one path whose point is recovering it safely. What comes back is a handle plus the metadata the backup was given.
  ///
  /// [key] is the half the user kept or the key server held; the derivation path travels inside [file]. A file that is not a vault, or a key that does not open it, is an [InvalidVaultFailure] and nothing is stored.
  ///
  /// ⚠️ **A vault carries the words alone**, so pass [passphrase] to restore the wallet the user actually had. Without it the result is a [WordsOnly] — restored, storable, usable, and a different Bitcoin wallet if there ever was a passphrase. [WholeSecret] says the passphrase took part, not that it was the right one: there is nothing in the file to check it against, so a mistyped passphrase restores a third wallet, silently. Let the user confirm on a balance or an address they recognise. See doc/design.md, § Passphrase.
  Future<Result<PassphraseScope<RestoredVault>, SecretFailure>> restoreVault({
    required String file,
    required String key,
    String? passphrase,
  }) async =>
      (await _repository.restore(
        file: file,
        key: key,
        passphrase: passphrase,
      )).map((r) {
        log.info('SECRET_RESTORE: vault opened into ${r.info.id}');
        // Inverted on purpose: a restore that stored a passphrase used
        // the whole secret, and one that did not is words-only — which is
        // the opposite of what the same flag means for a derivation.
        final restored = (secret: _handle(r.info), metadata: r.metadata);
        return r.info.hasPassphrase
            ? WholeSecret(restored)
            : WordsOnly(restored);
      });

  // ------------------------------------------------------------------ repair

  /// Re-files a secret under the identity it really has.
  ///
  /// The remedy for [SecretIdentityMismatchFailure], which says the words
  /// under a key derive to a different one — so the wallet the app joined on
  /// that fingerprint was never this secret's. Nothing leaves the package to
  /// fix it: the entry is moved, and what comes back is the handle for its
  /// true identity, under which the app can create the wallet it actually has.
  ///
  /// Idempotent. If the true identity is already taken by a different secret,
  /// this refuses and nothing is lost — the user re-imports their backup for
  /// the original fingerprint instead.
  Future<Result<Secret, SecretFailure>> repairIdentity(Fingerprint id) async =>
      (await _repository.repairIdentity(id)).map(_handle);

  // ----------------------------------------------------------- database keys

  /// The encryption key for one package's database.
  ///
  /// Thirty-two random bytes, generated on first ask, kept in this package's namespace. Not user material: it opens one local database and cannot reach a seed or another package's database. First asks are atomic process-wide. A stored value that is present but unusable is a [DatabaseKeyCorruptFailure] and is never written over.
  ///
  /// A package should not hold a [Secrets] to get one. Compose instead, so it can only ever name its own keys:
  ///
  /// ```dart
  /// Swaps(databaseKey: (name) =>
  ///     secrets.databaseKey(package: 'swaps', name: name));
  /// ```
  Future<Result<DatabaseKey, SecretFailure>> databaseKey({
    required String package,
    required String name,
  }) async {
    _requireModuleKeyArguments(package: package, name: name);
    return _databaseKeys.forModule(package: package, name: name);
  }

  /// The key for a database that already exists — opened, never created.
  ///
  /// Use it once the module knows its database is on disk: a miss is then a
  /// [SecretNotFoundFailure] and the owner decides, rather than a fresh key
  /// that opens nothing. [databaseKey] stays for the launch that may be
  /// creating the database.
  Future<Result<DatabaseKey, SecretFailure>> existingDatabaseKey({
    required String package,
    required String name,
  }) async {
    _requireModuleKeyArguments(package: package, name: name);
    return _databaseKeys.existing(package: package, name: name);
  }

  /// Discards one package's database key. **Destructive and deliberate**: the database that key encrypted can never be opened again, so the caller drops that database in the same step. A corrupt key is never reset by recovery code; this exists for the module owner to call after deciding to lose the database.
  Future<Result<void, SecretFailure>> resetDatabaseKey({
    required String package,
    required String name,
  }) async {
    _requireModuleKeyArguments(package: package, name: name);
    return _databaseKeys.reset(package: package, name: name);
  }

  /// Caller misuse is an [ArgumentError], raised *before* the boundary: the
  /// caller then reads this package's own message, not a redacted type name.
  /// The datasource asserts the same shape when it composes the key.
  static void _requireModuleKeyArguments({
    required String package,
    required String name,
  }) {
    for (final (label, segment) in [('package', package), ('name', name)]) {
      if (segment.isEmpty || segment.contains('/')) {
        throw ArgumentError.value(
          segment,
          label,
          'must be non-empty and free of "/"',
        );
      }
    }
  }

  Secret _handle(SecretInfo info) => Secret(
    info,
    repository: _repository,
    scratchDirectory: _scratchDirectory,
  );
}

/// What a restored vault gives back: the secret, and the caller's own
/// fields — never the words. `Secret.toString` prints an id, so this
/// prints nothing sensitive either.
typedef RestoredVault = ({Secret secret, Map<String, dynamic> metadata});
