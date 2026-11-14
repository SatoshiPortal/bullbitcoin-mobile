import 'dart:convert';
import 'dart:math';

import 'package:secrets/src/domain/domain.dart' show languageFromLabel;

import 'package:bip85_entropy/bip85_entropy.dart';
import 'package:convert/convert.dart' as convert;
import 'package:recoverbull/recoverbull.dart';
import 'package:secrets/src/crypto/derivers/fingerprint_deriver.dart';
import 'package:secrets/src/crypto/exceptions.dart';
import 'package:meta/meta.dart';

/// The RecoverBull vault: seals and opens it, and derives the BIP85 key
/// behind it. The sealed result is an `EncryptedVault`. Reached as
/// `Backup.recoverbull`.
///
/// Lives in this package because the plaintext it seals **is** the user's
/// mnemonic, and the key that seals it is derived from the same seed. A
/// caller that could assemble the plaintext would already hold the
/// words; a caller that could derive the key would hold an xprv. Both
/// belong on this side of the boundary, so the whole operation does.
///
/// The on-disk shape is fixed by the recovery protocol and by vaults
/// already in users' hands: the plaintext is a JSON object with the
/// words under [_kMnemonic] alongside whatever the caller adds, and the
/// encrypted file carries its own derivation path under `path`.
final class RecoverBullBackup {
  @internal
  const RecoverBullBackup();

  /// BIP85 application number RecoverBull reserves for backup keys.
  static final _application = CustomApplication.fromNumber(1608);

  static const _kMnemonic = 'mnemonic';
  // Not `language`: vaults sealed before languages existed may carry that
  // key as caller metadata, which must still come back untouched.
  static const _kLanguage = 'mnemonicLanguage';
  static const _kPath = 'path';

  /// A fresh `1608'/0'/<random>'` path.
  ///
  /// The index is random rather than sequential so two backups of the
  /// same wallet do not share a key, and so a leaked key reveals nothing
  /// about the others.
  String newDerivationPath() => Bip85HardenedPath(
    "${_application.number}'/0'/${_randomIndex()}'",
  ).toString();

  /// The 32-byte backup key for [path], as hex.
  String backupKey({required String masterXprv, required String path}) {
    final derived = Bip85Entropy.derive(
      xprvBase58: masterXprv,
      application: _application,
      path: _pathSuffix(path),
    );
    return convert.hex.encode(derived.sublist(0, 32));
  }

  /// Validates the historical and current path spellings in a vault file.
  String derivationPath(String file) {
    final Object? decoded;
    try {
      decoded = json.decode(file);
    } on FormatException {
      throw const InvalidVault('file is not a RecoverBull vault');
    }
    final path = decoded is Map<String, dynamic> ? decoded[_kPath] : null;
    if (path is! String ||
        !RegExp(r"^(?:m/)?1608'/0'/[0-9]+'?$").hasMatch(path)) {
      throw const InvalidVault('vault derivation path is invalid');
    }
    final index = int.tryParse(path.split('/').last.replaceAll("'", ''));
    if (index == null || index > 0x7fffffff) {
      throw const InvalidVault('vault derivation path is invalid');
    }
    return path;
  }

  /// Seals [words] together with [metadata] under [backupKey].
  ///
  /// [metadata] is whatever the caller wants restored alongside the
  /// mnemonic — backup timestamps, test flags. It must not contain a
  /// `mnemonic` or `mnemonicLanguage` entry: those belong to the vault.
  /// Reserved plaintext keys may not be supplied as caller metadata.
  Set<String> get reservedMetadataKeys => const {_kMnemonic, _kLanguage};

  String seal({
    required List<String> words,
    required Language language,
    required Map<String, dynamic> metadata,
    required String backupKey,
    required String derivationPath,
  }) {
    // Validated by `Secret.backupRecoverbull` before the boundary, where the
    // caller still gets an ArgumentError with this package's message.
    assert(
      !metadata.keys.any(reservedMetadataKeys.contains),
      'the mnemonic is written by the vault, not by the caller',
    );

    final plaintext = json.encode({
      ...metadata,
      _kMnemonic: words,
      _kLanguage: language.label,
    });
    final sealed = RecoverBull.createBackup(
      secret: utf8.encode(plaintext),
      backupKey: convert.hex.decode(_normalize(backupKey)),
    ).toJson();

    // The path travels with the file so a restore can re-derive the key
    // from the seed alone.
    final file = json.decode(sealed) as Map<String, dynamic>;
    file[_kPath] = derivationPath;
    return json.encode(file);
  }

  /// Opens [file] with [backupKey] and splits it back apart.
  ///
  /// Returns the words separately from the rest so the caller can hand
  /// the words straight to storage without ever holding the whole
  /// plaintext.
  ///
  /// Every way this can fail is an [InvalidVault] with one of this
  /// file's own messages: the libraries' messages are not carried, and
  /// the stages are kept apart so a wrong key reads differently from a
  /// file that was never a vault.
  ({List<String> words, Language language, Map<String, dynamic> metadata})
  open({required String file, required String backupKey}) {
    final BullBackup backup;
    try {
      backup = BullBackup.fromJson(file);
    } on Exception {
      throw const InvalidVault('file is not a RecoverBull vault');
    }

    final List<int> opened;
    try {
      opened = RecoverBull.restoreBackup(
        backup: backup,
        backupKey: convert.hex.decode(_normalize(backupKey)),
      );
    } on Exception {
      // A wrong key and a tampered ciphertext are indistinguishable by
      // design: the MAC fails either way.
      throw const InvalidVault('key does not open this vault');
    }

    final Object? plaintext;
    try {
      plaintext = json.decode(utf8.decode(opened));
    } on FormatException {
      throw const InvalidVault('vault plaintext is not JSON');
    }
    if (plaintext is! Map<String, dynamic>) {
      throw const InvalidVault('vault plaintext is not an object');
    }

    final Language language;
    try {
      language = plaintext.containsKey(_kLanguage)
          ? languageFromLabel(plaintext.remove(_kLanguage))
          : Language.english;
    } on FormatException {
      throw const InvalidVault('vault carries an unknown mnemonic language');
    }
    // Check elements eagerly; a lazy cast would defer invalid plaintext.
    final words = plaintext.remove(_kMnemonic);
    if (words is! List || words.isEmpty || words.any((w) => w is! String)) {
      throw const InvalidVault('vault carries no mnemonic');
    }
    // A count BIP39 does not define is decided here, where the words came from a vault, so it reads as "invalid vault" — and not two layers down in the storage model, where it would read as a store failure.
    if (!const {12, 15, 18, 21, 24}.contains(words.length)) {
      throw const InvalidVault('vault mnemonic has an invalid word count');
    }
    // Wordlist, checksum and element boundaries, so that a vault whose words
    // are not a mnemonic reads as an invalid vault and never as an invalid
    // *import*. Routed through the one validator rather than calling bip39
    // here: `fromWords` joins the list and re-splits it, so on its own it
    // would accept a list whose elements are several words each and leave
    // that list to be stored. `check` derives no seed.
    try {
      const FingerprintDeriver().check(
        List<String>.from(words),
        language: language,
      );
    } on MnemonicException {
      throw const InvalidVault('vault mnemonic is not a valid BIP39 mnemonic');
    }
    return (
      words: List<String>.from(words),
      language: language,
      metadata: plaintext,
    );
  }

  /// Strips the application number, which `Bip85Entropy.derive` supplies
  /// itself. Tolerates the historical `m/` prefix: rust-bip85 emitted one
  /// before the fork, so paths of both shapes exist in the wild.
  static String _pathSuffix(String path) =>
      path.replaceAll('m/', '').replaceAll("${_application.number}'/", '');

  static String _normalize(String hex) =>
      hex.startsWith('0x') ? hex.substring(2) : hex;

  static int _randomIndex() => Random.secure().nextInt(1 << 31);
}
