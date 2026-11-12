import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:bip39_mnemonic/bip39_mnemonic.dart'
    show Language, MnemonicException;
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/crypto.dart'
    show Backup, Deriver, Descriptors;
import 'package:secrets/src/data/boundary.dart';
import 'package:secrets/src/data/exceptions.dart';
import 'package:secrets/src/data/fss_datasource.dart';
import 'package:secrets/src/data/models/secret_model.dart';
import 'package:secrets/src/domain/domain.dart';
import 'package:meta/meta.dart';

/// Maps the stored shape to live key material, and to descriptions of it — and is where every exception becomes a [SecretFailure].
///
/// The only place [SecretModel] and [SecretMaterial] meet. Material never leaves as a value: [use] and [useMnemonic] load it, run the caller's closure on it and let it go, so a caller can derive or sign without ever holding a seed. Descriptions ([describe], [describeAll]) derive nothing — the fingerprint *is* the storage key.
///
/// Concrete by derogation to AGENTS.md rule 6 (2026-09-15): tests substitute below it, at `FlutterSecureStoragePlatform.instance`.
class SecretRepository {
  final _source = FlutterSecureStorageDatasource();

  @internal
  SecretRepository();

  // ------------------------------------------------------------------- reads

  /// One secret's description. Absence is concluded only once the datasource's read has settled.
  Future<Result<SecretInfo, SecretFailure>> describe(Fingerprint id) =>
      _read(id, (model) => _describe(id, model));

  /// Describes every stored secret without materialising any of them. An unreadable value becomes an individual failure without hiding the other entries.
  Future<Result<InfoListing, SecretFailure>> describeAll() =>
      boundary(() async {
        final listing = await _source.fetchAllSecrets();
        final unreadable = <({Fingerprint? id, SecretFailure failure})>[
          for (final id in listing.unparsable)
            (id: id, failure: const FetchSecretFailure('invalid stored entry')),
        ];
        final described = await Future.wait(
          listing.parsed.map((e) async {
            try {
              return await _describe(e.id, e.model);
            } on FormatException {
              log.warning('Skipping secret ${e.id}: stored words fail bip39');
              unreadable.add((
                id: e.id,
                failure: const FetchSecretFailure('stored words fail bip39'),
              ));
              return null;
            }
          }),
        );
        final infos = described.nonNulls.toList();
        return SecretListing(secrets: infos, unreadable: unreadable);
      }, orElse: FetchSecretFailure.new);

  /// Runs [body] on the secret's material, which exists only for the call.
  ///
  /// A read that fails is a [FetchSecretFailure]; [body] raising is a [UseSecretFailure], so a bad PSBT never reads as an unreadable seed.
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
        orElse: UseSecretFailure.new,
      ),
    };
  }

  /// [use], for operations that need BIP39 words. A seed-only secret is refused from [info] alone, before any PBKDF2.
  Future<Result<T, SecretFailure>> useMnemonic<T>(
    SecretInfo info,
    FutureOr<T> Function(Mnemonic material) body,
  ) {
    if (!info.isMnemonic) {
      return Future.value(
        const Err(MnemonicRequiredFailure('operation requires a mnemonic')),
      );
    }
    return use(info, (material) {
      // Unreachable while `materialize` checks the key: a seed-only model cannot derive to a mnemonic's fingerprint.
      if (material is! Mnemonic) {
        throw const FingerprintMismatchException(
          'stored secret carries no words',
        );
      }
      return body(material);
    });
  }

  /// Whether a secret exists, best-effort. See [FlutterSecureStorageDatasource.secretExists].
  Future<Result<bool, SecretFailure>> exists(Fingerprint id) =>
      boundary(() => _source.secretExists(id), orElse: FetchSecretFailure.new);

  /// Fingerprint a candidate mnemonic would have, without storing it.
  Future<Result<Fingerprint, SecretFailure>> idOf({
    required List<String> words,
    Language language = Language.english,
    String? passphrase,
  }) => boundary(
    () => Isolate.run(
      () => Deriver.fingerprint.fingerprint(
        Deriver.fingerprint.seed(
          words,
          passphrase: passphrase ?? '',
          language: language,
        ),
      ),
    ),
    orElse: InvalidMnemonicFailure.new,
  );

  /// Public descriptors of words that are not stored, for each of [scriptTypes]: nothing is read from or written to the keystore.
  ///
  /// One seed serves every script type, so the PBKDF2 runs once. It is derived, used and wiped inside one isolate; only the public descriptor strings cross back. The material is seed-only, so no library ever receives the words. Invalid words are an [InvalidMnemonicFailure]; a failed derivation is a [UseSecretFailure].
  Future<Result<Map<ScriptType, Descriptors>, SecretFailure>>
  previewBitcoinDescriptors({
    required List<String> words,
    required Language language,
    String? passphrase,
    required BitcoinNetwork network,
    required Set<ScriptType> scriptTypes,
  }) {
    // Copied now: the derivation runs in another isolate, after the caller may have reused its list.
    final candidate = List<String>.of(words);
    final types = Set<ScriptType>.of(scriptTypes);
    final pass = passphrase ?? '';
    return boundary(
      () => Isolate.run(
        () => _previewDescriptors(
          words: candidate,
          language: language,
          passphrase: pass,
          network: network,
          scriptTypes: types,
        ),
      ),
      // Invalid words are bip39's exception, which the boundary maps to [InvalidMnemonicFailure] on its own; anything else failed the derivation.
      orElse: UseSecretFailure.new,
    );
  }

  // ------------------------------------------------------------------ writes

  /// Stores a mnemonic and returns its description. Mnemonics are the only kind anything writes; [Seed] stays readable for entries that predate that.
  Future<Result<SecretInfo, SecretFailure>> store({
    required List<String> words,
    Language language = Language.english,
    String? passphrase,
    bool rejectExisting = false,
    Set<Fingerprint>? acceptOnly,
  }) => boundary(() async {
    // Validated as words first — count, wordlist, checksum — so a bad count reads as "invalid mnemonic" like a bad checksum, not as the model's FormatException. Cheap: no seed yet.
    final normalized = Deriver.fingerprint.normalizeWords(words);
    Deriver.fingerprint.check(normalized, language: language);
    final model = MnemonicSecretModel(
      mnemonicWords: normalized,
      language: language,
      // Absent and empty are one passphrase to BIP39 and to this package; the
      // disk has always said `null` for it, so a fresh write says the same.
      passphrase: (passphrase == null || passphrase.isEmpty)
          ? null
          : passphrase,
    );
    final id = await Isolate.run(() => _identify(model));
    // Checked before the write, so a refusal never depends on undoing one.
    if (acceptOnly != null && !acceptOnly.contains(id)) {
      throw const FingerprintMismatchException(
        'the words do not derive to an accepted fingerprint',
      );
    }
    // Restoration may keep an equivalent entry in another wordlist: describe
    // that one, since every later operation reads it, not the candidate.
    final kept = await _source.storeSecret(
      id: id,
      secret: model,
      seedOf: (m) => Isolate.run(() => _seedOf(m)),
      rejectExisting: rejectExisting,
    );
    return _describe(id, kept);
  }, orElse: StoreSecretFailure.new);

  /// Compares the full seed, not merely the collision-prone fingerprint.
  Future<Result<bool, SecretFailure>> contains({
    required List<String> words,
    Language language = Language.english,
    String? passphrase,
  }) {
    final candidate = List<String>.of(words);
    return boundary(() async {
      final seed = await Isolate.run(
        () => Deriver.fingerprint.seed(
          candidate,
          passphrase: passphrase ?? '',
          language: language,
        ),
      );
      final id = Deriver.fingerprint.fingerprint(seed);
      final stored = await _source.fetchSecret(id);
      if (stored == null) return false;
      final existing = await _readOffIsolate(() => _seedOf(stored));
      if (seed.length != existing.length) return false;
      var difference = 0;
      for (var i = 0; i < seed.length; i++) {
        difference |= seed[i] ^ existing[i];
      }
      return difference == 0;
    }, orElse: FetchSecretFailure.new);
  }

  /// Opens a RecoverBull vault and stores the words it carries, under [passphrase] when the user supplied one. The words exist only inside this call.
  Future<Result<RestoredSecret, SecretFailure>> restore({
    required String file,
    required String key,
    String? passphrase,
  }) async {
    final opened = await boundary(
      () async => Backup.recoverbull.open(file: file, backupKey: key),
      orElse: StoreSecretFailure.new,
    );
    return switch (opened) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => (await store(
        words: value.words,
        language: value.language,
        passphrase: passphrase,
      )).map((info) => (info: info, metadata: value.metadata)),
    };
  }

  /// Inspects a RecoverBull vault without reading or writing the keystore. Only its validated mnemonic determines the fingerprint; metadata is not trusted for it.
  Future<Result<Fingerprint, SecretFailure>> inspect({
    required String file,
    required String key,
  }) => boundary(
    () => Isolate.run(() {
      final opened = Backup.recoverbull.open(file: file, backupKey: key);
      return Deriver.fingerprint.fingerprint(
        Deriver.fingerprint.seed(opened.words, language: opened.language),
      );
    }),
    orElse: UseSecretFailure.new,
  );

  Future<Result<void, SecretFailure>> trash(Fingerprint id) =>
      boundary(() => _source.trashSecret(id), orElse: TrashSecretFailure.new);

  // ----------------------------------------------------------------- private

  /// Reads one entry and projects it. The datasource's `null` — a settled read that found nothing — is the one path to [SecretNotFoundFailure]; anything the entry then refuses is a read failure, never an absence.
  Future<Result<T, SecretFailure>> _read<T>(
    Fingerprint id,
    Future<T> Function(SecretModel model) project,
  ) async {
    final fetched = await boundary(
      () => _source.fetchSecret(id),
      orElse: FetchSecretFailure.new,
    );
    return switch (fetched) {
      Err(:final failure) => Err(failure),
      Ok(value: null) => const Err(
        SecretNotFoundFailure('no secret under that id'),
      ),
      Ok(value: final SecretModel model) => await boundary(
        () => project(model),
        orElse: FetchSecretFailure.new,
      ),
    };
  }

  /// Projects a stored model onto its description without deriving a seed.
  ///
  /// Words that no longer pass bip39 are refused for every entry, with or without a passphrase. Validation checks the wordlist and checksum without deriving a seed.
  Future<SecretInfo> _describe(Fingerprint id, SecretModel model) async {
    switch (model) {
      case BytesSecretModel(:final bytes):
        return SecretInfo.seed(id: id, lengthInBits: bytes.length * 8);
      case MnemonicSecretModel(
        :final mnemonicWords,
        :final passphrase,
        :final language,
      ):
        try {
          Deriver.fingerprint.check(mnemonicWords, language: language);
        } on MnemonicException {
          throw const FormatException('stored words are not a BIP39 mnemonic');
        }
        final hasPassphrase = passphrase != null && passphrase.isNotEmpty;
        return SecretInfo.mnemonic(
          id: id,
          wordCount: mnemonicWords.length,
          language: language,
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

  /// Runs in an isolate; static so it captures nothing but its arguments.
  ///
  /// The seed buffer is ours and is zeroed before the isolate returns. Copies made inside bip32_keys, bdk and the master xprv string are immutable or library-internal: they die with the isolate's heap, but their erasure cannot be guaranteed.
  static Future<Map<ScriptType, Descriptors>> _previewDescriptors({
    required List<String> words,
    required Language language,
    required String passphrase,
    required BitcoinNetwork network,
    required Set<ScriptType> scriptTypes,
  }) async {
    final seed = Deriver.fingerprint.seed(
      words,
      passphrase: passphrase,
      language: language,
    );
    try {
      final material = Seed(
        id: Deriver.fingerprint.fingerprint(seed),
        seedBytes: seed,
      );
      return {
        for (final scriptType in scriptTypes)
          scriptType: await Deriver.bitcoin.descriptors(
            material,
            scriptType: scriptType,
            network: network,
          ),
      };
    } finally {
      seed.fillRange(0, seed.length, 0);
    }
  }

  /// Runs in an isolate; static so it stays sendable.
  ///
  /// The key is checked against the material, not trusted: the entry was filed under the fingerprint derived at write time, and serving a value that derives elsewhere would hand one wallet's keys under another's fingerprint. One fingerprint over a seed already computed.
  static SecretMaterial materialize(Fingerprint id, SecretModel model) {
    final material = _materialize(id, model);
    if (Deriver.fingerprint.fingerprint(material.seedBytes) != id) {
      throw FingerprintMismatchException(
        'stored secret does not derive to ${id.hex}',
      );
    }
    return material;
  }

  static SecretMaterial _materialize(Fingerprint id, SecretModel model) {
    switch (model) {
      case BytesSecretModel(:final bytes):
        return Seed(id: id, seedBytes: Uint8List.fromList(bytes));
      case MnemonicSecretModel(
        :final mnemonicWords,
        :final passphrase,
        :final language,
      ):
        final pass = passphrase ?? '';
        return Mnemonic(
          id: id,
          words: mnemonicWords,
          language: language,
          passphrase: pass,
          seedBytes: Deriver.fingerprint.seed(
            mnemonicWords,
            passphrase: pass,
            language: language,
          ),
        );
    }
  }

  static Fingerprint _identify(SecretModel model) => switch (model) {
    BytesSecretModel(:final bytes) => Deriver.fingerprint.fingerprint(
      Uint8List.fromList(bytes),
    ),
    MnemonicSecretModel(
      :final mnemonicWords,
      :final passphrase,
      :final language,
    ) =>
      Deriver.fingerprint.fingerprint(
        Deriver.fingerprint.seed(
          mnemonicWords,
          passphrase: passphrase ?? '',
          language: language,
        ),
      ),
  };

  /// The full seed a model derives to. For the one comparison a fingerprint is not enough for — see `FlutterSecureStorageDatasource._holdsSameSecret`.
  static Uint8List _seedOf(SecretModel model) => switch (model) {
    BytesSecretModel(:final bytes) => Uint8List.fromList(bytes),
    MnemonicSecretModel(
      :final mnemonicWords,
      :final passphrase,
      :final language,
    ) =>
      Deriver.fingerprint.seed(
        mnemonicWords,
        passphrase: passphrase ?? '',
        language: language,
      ),
  };
}

/// What [SecretRepository.restore] hands back: the description and the caller's own metadata, never the words.
typedef RestoredSecret = ({SecretInfo info, Map<String, dynamic> metadata});
