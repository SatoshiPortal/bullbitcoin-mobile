import 'dart:convert';

import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:convert/convert.dart' as convert;
import 'package:flutter_test/flutter_test.dart';
import 'package:recoverbull/recoverbull.dart';
import 'package:secrets/src/crypto/crypto.dart' show Backup;
import 'package:secrets/src/crypto/exceptions.dart' show InvalidVault;
import 'package:secrets/src/data/models/secret_model.dart';

/// The stored and vault spellings of each wordlist are a frozen contract: bip39's `Language.label`, never the Dart identifiers of the bip39 package. Pinned here so a change of label in bip39 cannot silently change bytes on devices.
void main() {
  const golden = {
    bip39.Language.english: 'english',
    bip39.Language.japanese: 'japanese',
    bip39.Language.korean: 'korean',
    bip39.Language.spanish: 'spanish',
    bip39.Language.simplifiedChinese: 'chinese-simplified',
    bip39.Language.traditionalChinese: 'chinese-traditional',
    bip39.Language.french: 'french',
    bip39.Language.italian: 'italian',
    bip39.Language.czech: 'czech',
    bip39.Language.portuguese: 'portuguese',
  };
  const backupKey =
      '0000000000000000000000000000000000000000000000000000000000000000';

  test('the table covers every wordlist', () {
    expect(golden.keys.toSet(), bip39.Language.values.toSet());
  });

  Map<String, dynamic> plaintextOf(String vault) => jsonDecode(
    utf8.decode(
      RecoverBull.restoreBackup(
        backup: BullBackup.fromJson(vault),
        backupKey: convert.hex.decode(backupKey),
      ),
    ),
  ) as Map<String, dynamic>;

  String vaultWith(Map<String, dynamic> plaintext) => RecoverBull.createBackup(
    secret: utf8.encode(jsonEncode(plaintext)),
    backupKey: convert.hex.decode(backupKey),
  ).toJson();

  for (final MapEntry(key: language, value: wire) in golden.entries) {
    final words = bip39.Mnemonic(List.filled(16, 0), language).words;

    test('storage writes and reads $wire', () {
      final json = MnemonicSecretModel(
        mnemonicWords: words,
        language: language,
      ).toJson();
      if (language == bip39.Language.english) {
        expect(json.containsKey('language'), isFalse);
      } else {
        expect(json['language'], wire);
      }
      final decoded = SecretModel.fromJson({
        'mnemonicWords': words,
        'passphrase': null,
        'runtimeType': 'mnemonic',
        'language': wire,
      }) as MnemonicSecretModel;
      expect(decoded.language, language);
    });

    test('vault writes and reads $wire', () {
      final sealed = Backup.recoverbull.seal(
        words: words,
        language: language,
        metadata: const {},
        backupKey: backupKey,
        derivationPath: Backup.recoverbull.newDerivationPath(),
      );
      final plaintext = plaintextOf(sealed);
      expect(plaintext['mnemonicLanguage'], wire);
      final opened = Backup.recoverbull.open(
        file: vaultWith({'mnemonic': words, 'mnemonicLanguage': wire}),
        backupKey: backupKey,
      );
      expect(opened.language, language);
      expect(opened.metadata, isEmpty);
    });
  }

  test('the bip39 package identifiers are not wire values', () {
    final words = bip39.Mnemonic(
      List.filled(16, 0),
      bip39.Language.simplifiedChinese,
    ).words;
    for (final identifier in ['simplifiedChinese', 'traditionalChinese']) {
      expect(
        () => SecretModel.fromJson({
          'mnemonicWords': words,
          'passphrase': null,
          'runtimeType': 'mnemonic',
          'language': identifier,
        }),
        throwsFormatException,
      );
      expect(
        () => Backup.recoverbull.open(
          file: vaultWith({'mnemonic': words, 'mnemonicLanguage': identifier}),
          backupKey: backupKey,
        ),
        throwsA(isA<InvalidVault>()),
      );
    }
  });
}
