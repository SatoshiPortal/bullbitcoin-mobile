import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:bip39_mnemonic/bip39_mnemonic.dart' show MnemonicException;
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/crypto.dart' show Backup, Deriver;
import 'package:secrets/src/data/boundary.dart';
import 'package:secrets/src/data/exceptions.dart';
import 'package:secrets/src/data/fss_datasource.dart';
import 'package:secrets/src/data/models/secret_model.dart';
import 'package:secrets/src/domain/domain.dart';

/// Maps the stored shape to live key material, and to descriptions of it — and is where every exception becomes a [SecretFailure].
///
/// The only place [SecretModel] and [SecretMaterial] meet. Material never leaves as a value: [use] and [useMnemonic] load it, run the caller's closure on it and let it go, so a caller can derive or sign without ever holding a seed. Descriptions ([describe], [describeAll]) derive nothing — the fingerprint *is* the storage key.
///
/// Concrete by derogation to AGENTS.md rule 6 (2026-09-15): tests substitute below it, at `FlutterSecureStoragePlatform.instance`.
class SecretRepository {
  final _source = FlutterSecureStorageDatasource();

  SecretRepository();

  // ------------------------------------------------------------------- reads

  /// One secret's description. Absence is concluded only after the datasource's full retry loop.
  Future<Result<SecretInfo, SecretFailure>> describe(Fingerprint id) =>
      _read(id, (model) => _describe(id, model));

  /// Describes every stored secret without materialising any of them. An entry whose words no longer pass bip39 is skipped, like one that does not parse: one corrupt value must not hide the others.
  Future<Result<List<SecretInfo>, SecretFailure>> describeAll() =>
      boundary(() async {
        final stored = await _source.fetchAllSecrets();
        final described = await Future.wait(
          stored.map((e) async {
            try {
              return await _describe(e.id, e.model);
            } on FormatException {
              log.warning('Skipping secret ${e.id}: stored words fail bip39');
              return null;
            }
          }),
        );
        return described.nonNulls.toList();
      }, orElse: SecretFetchFailure.new);

  /// Runs [body] on the secret's material, which exists only for the call.
  ///
  /// A read that fails is a [SecretFetchFailure]; [body] raising is a [SecretDerivationFailure], so a bad PSBT never reads as an unreadable seed.
  Future<Result<T, SecretFailure>> use<T>(
    SecretInfo info,
    FutureOr<T> Function(SecretMaterial material) body,
  ) async {
    final id = info.id;
    final loaded = await _read(
      id,
      (model) => _readOffIsolate(() => materialize(id, model)),
    );
    return switch (loaded) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => await boundary(
        () async => await body(value),
        orElse: SecretDerivationFailure.new,
      ),
    };
  }

  /// [use], for operations that need BIP39 words. A seed-only secret is refused from [info] alone, before any PBKDF2.
  Future<Result<T, SecretFailure>> useMnemonic<T>(
    SecretInfo info,
    FutureOr<T> Function(MnemonicMaterial material) body,
  ) {
    if (!info.isMnemonic) {
      return Future.value(
        const Err(MnemonicRequiredFailure('operation requires a mnemonic')),
      );
    }
    return use(info, (material) {
      // Unreachable while `materialize` checks the key: a seed-only model cannot derive to a mnemonic's fingerprint.
      if (material is! MnemonicMaterial) {
        throw const SecretIdentityMismatch('stored secret carries no words');
      }
      return body(material);
    });
  }

  /// Whether a secret exists, best-effort. See [FlutterSecureStorageDatasource.secretExists].
  Future<Result<bool, SecretFailure>> exists(Fingerprint id) =>
      boundary(() => _source.secretExists(id), orElse: SecretFetchFailure.new);

  /// Identity a candidate mnemonic would have, without storing it.
  Future<Result<Fingerprint, SecretFailure>> idOf({
    required List<String> words,
    String? passphrase,
  }) => boundary(
    () => Isolate.run(
      () => Deriver.identity.fingerprint(
        Deriver.identity.seed(words, passphrase: passphrase ?? ''),
      ),
    ),
    orElse: InvalidMnemonicFailure.new,
  );

  // ------------------------------------------------------------------ writes

  /// Stores a mnemonic and returns its description. Mnemonics are the only kind anything writes; [SeedMaterial] stays readable for entries that predate that.
  Future<Result<SecretInfo, SecretFailure>> store({
    required List<String> words,
    String? passphrase,
  }) => boundary(() async {
    // Validated as words first — count, wordlist, checksum — so a bad count reads as "invalid mnemonic" like a bad checksum, not as the model's FormatException. Cheap: no seed yet.
    Deriver.identity.check(words);
    final model = MnemonicSecretModel(
      mnemonicWords: words,
      passphrase: passphrase,
    );
    final id = await Isolate.run(() => _identify(model));
    await _source.storeSecret(id: id, secret: model);
    return _describe(id, model);
  }, orElse: SecretStoreFailure.new);

  /// Opens a RecoverBull vault and stores the words it carries, under [passphrase] when the user supplied one. The words exist only inside this call.
  Future<Result<RestoredSecret, SecretFailure>> restore({
    required String file,
    required String key,
    String? passphrase,
  }) async {
    final opened = await boundary(
      () async => Backup.recoverbull.open(file: file, backupKey: key),
      orElse: SecretStoreFailure.new,
    );
    return switch (opened) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => (await store(
        words: value.words,
        passphrase: passphrase,
      )).map((info) => (info: info, metadata: value.metadata)),
    };
  }

  /// Re-files an entry under the identity it really has.
  ///
  /// The remedy for [SecretIdentityMismatchFailure]: the words are intact, only the key they are under is wrong, so nothing needs to leave the package to fix it. Idempotent — an entry already under its own identity is simply described.
  ///
  /// The move is a write then a delete, in that order, so a crash in between leaves both copies rather than none. If the true identity is already taken by a *different* secret, the write refuses and the original is untouched.
  Future<Result<SecretInfo, SecretFailure>> repairIdentity(
    Fingerprint id,
  ) async {
    final derived = await _read(
      id,
      (model) => Isolate.run(() => _identify(model)),
    );
    return switch (derived) {
      Err(:final failure) => Err(failure),
      Ok(value: final actual) when actual == id => describe(id),
      Ok(value: final actual) => await boundary(() async {
        final model = await _source.fetchSecret(id);
        if (model == null) {
          throw const FormatException('the entry vanished mid-repair');
        }
        await _source.storeSecret(id: actual, secret: model);
        await _source.trashSecret(id);
        log.info('SECRET_REPAIR: $id re-filed under $actual');
        return _describe(actual, model);
      }, orElse: SecretStoreFailure.new),
    };
  }

  Future<Result<void, SecretFailure>> trash(Fingerprint id) =>
      boundary(() => _source.trashSecret(id), orElse: SecretDeleteFailure.new);

  // ----------------------------------------------------------------- private

  /// Reads one entry and projects it. The datasource's `null` — a full read through the retry loop that found nothing — is the one path to [SecretNotFoundFailure]; anything the entry then refuses is a read failure, never an absence.
  Future<Result<T, SecretFailure>> _read<T>(
    Fingerprint id,
    Future<T> Function(SecretModel model) project,
  ) async {
    final fetched = await boundary(
      () => _source.fetchSecret(id),
      orElse: SecretFetchFailure.new,
    );
    return switch (fetched) {
      Err(:final failure) => Err(failure),
      Ok(value: null) => const Err(
        SecretNotFoundFailure('no secret under that id'),
      ),
      Ok(value: final SecretModel model) => await boundary(
        () => project(model),
        orElse: SecretFetchFailure.new,
      ),
    };
  }

  /// Projects a stored model onto its description. Derives only when a passphrase splits the two identities; that pass goes off-isolate.
  Future<SecretInfo> _describe(Fingerprint id, SecretModel model) async {
    switch (model) {
      case BytesSecretModel(:final bytes):
        return SecretInfo.bytes(id: id, lengthInBits: bytes.length * 8);
      case MnemonicSecretModel(:final mnemonicWords, :final passphrase):
        final hasPassphrase = passphrase != null && passphrase.isNotEmpty;
        return SecretInfo.mnemonic(
          id: id,
          mnemonicFingerprint: hasPassphrase
              ? await _readOffIsolate(() => _plainFingerprint(mnemonicWords))
              : id,
          wordCount: mnemonicWords.length,
          hasPassphrase: hasPassphrase,
        );
    }
  }

  /// A derivation on *stored* words. They passed bip39 when written, so a refusal now is a corrupt entry — a read failure, like a value that does not parse — not an "invalid mnemonic", which is what user-typed words get in [store].
  static Future<T> _readOffIsolate<T>(T Function() body) async {
    try {
      return await Isolate.run(body);
    } on MnemonicException {
      throw const FormatException('stored words are not a BIP39 mnemonic');
    }
  }

  /// Runs in an isolate; static so it stays sendable.
  ///
  /// The key is checked against the material, not trusted: the entry was filed under the fingerprint derived at write time, and serving a value that derives elsewhere would hand one wallet's keys under another's identity. One fingerprint over a seed already computed.
  static SecretMaterial materialize(Fingerprint id, SecretModel model) {
    final material = _materialize(id, model);
    if (Deriver.identity.fingerprint(material.seedBytes) != id) {
      throw SecretIdentityMismatch(
        'stored secret does not derive to ${id.hex}',
      );
    }
    return material;
  }

  static SecretMaterial _materialize(Fingerprint id, SecretModel model) {
    switch (model) {
      case BytesSecretModel(:final bytes):
        return SeedMaterial(id: id, seedBytes: Uint8List.fromList(bytes));
      case MnemonicSecretModel(:final mnemonicWords, :final passphrase):
        final pass = passphrase ?? '';
        return MnemonicMaterial(
          id: id,
          // A passphrase-less derivation is a second PBKDF2 pass; only pay it when a passphrase splits the two.
          mnemonicFingerprint: pass.isEmpty
              ? id
              : _plainFingerprint(mnemonicWords),
          words: mnemonicWords,
          passphrase: pass,
          seedBytes: Deriver.identity.seed(mnemonicWords, passphrase: pass),
        );
    }
  }

  static Fingerprint _identify(SecretModel model) => switch (model) {
    BytesSecretModel(:final bytes) => Deriver.identity.fingerprint(
      Uint8List.fromList(bytes),
    ),
    MnemonicSecretModel(:final mnemonicWords, :final passphrase) =>
      Deriver.identity.fingerprint(
        Deriver.identity.seed(mnemonicWords, passphrase: passphrase ?? ''),
      ),
  };

  static Fingerprint _plainFingerprint(List<String> words) =>
      Deriver.identity.fingerprint(Deriver.identity.seed(words));
}

/// What [SecretRepository.restore] hands back: the description and the caller's own metadata, never the words.
typedef RestoredSecret = ({SecretInfo info, Map<String, dynamic> metadata});
