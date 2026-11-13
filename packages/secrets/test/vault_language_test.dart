import 'dart:convert';

import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:convert/convert.dart' as convert;
import 'package:flutter_test/flutter_test.dart';
import 'package:recoverbull/recoverbull.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/src/crypto/crypto.dart' show Backup;
import 'package:secrets/testing.dart';

import 'result_helpers.dart';

void main() {
  late FakeSecureStoragePlatform storage;
  late Secrets secrets;
  setUp(() {
    storage = FakeSecureStoragePlatform()..install();
    secrets = Secrets(scratchDirectory: () async => '/tmp');
  });

  test('opens a Japanese vault without interpreting words as English', () {
    final words = [...List.filled(11, 'あいこくしん'), 'あおぞら'];
    final key = List<int>.filled(32, 0);
    final vault = RecoverBull.createBackup(
      secret: utf8.encode(
        jsonEncode({'mnemonic': words, 'mnemonicLanguage': 'japanese'}),
      ),
      backupKey: key,
    ).toJson();
    final opened = Backup.recoverbull.open(file: vault, backupKey: '00' * 32);
    expect(opened.metadata, isEmpty);
  });

  for (final language in Language.values) {
    for (final passphrase in ['', 'TREZOR']) {
      test(
        '${language.name} restores its own seed, passphrase: ${passphrase.isNotEmpty}',
        () async {
          final reference = bip39.Mnemonic(
            List.filled(16, 0),
            language,
            passphrase: passphrase,
          );
          final secret = ok(
            await secrets.import(
              words: reference.words,
              language: language,
              passphrase: passphrase,
            ),
          );
          final backup = ok(
            await secret.backup.recoverbull(
              metadata: {'label': 'published vector'},
            ),
          );
          final opened = Backup.recoverbull.open(
            file: backup.vault.json,
            backupKey: backup.key.hex,
          );
          expect(opened.language, language);
          expect(opened.metadata, {'label': 'published vector'});
          final plaintext =
              jsonDecode(
                    utf8.decode(
                      RecoverBull.restoreBackup(
                        backup: BullBackup.fromJson(backup.vault.json),
                        backupKey: convert.hex.decode(backup.key.hex),
                      ),
                    ),
                  )
                  as Map<String, dynamic>;
          if (language == bip39.Language.english) {
            const golden =
                '{"label":"published vector","mnemonic":["abandon","abandon","abandon","abandon","abandon","abandon","abandon","abandon","abandon","abandon","abandon","about"],"mnemonicLanguage":"english"}';
            expect(
              RecoverBull.restoreBackup(
                backup: BullBackup.fromJson(backup.vault.json),
                backupKey: convert.hex.decode(backup.key.hex),
              ),
              utf8.encode(golden),
            );
          }
          expect(plaintext.containsKey('mnemonicLanguage'), isTrue);
          if (language == bip39.Language.english) {
            expect(plaintext['mnemonicLanguage'], 'english');
          }
          expect(
            ok(await secret.backup.recoverbullKey(vault: backup.vault)).hex,
            backup.key.hex,
          );
          ok(await secrets.trash(secret.id));
          storage.locked = true;
          final inspected = ok(
            await secrets.recoverbull.fingerprint(
              vault: backup.vault,
              key: backup.key,
            ),
          );
          storage.locked = false;
          final restored = ok(
            await secrets.recoverbull.restore(
              vault: backup.vault,
              key: backup.key,
              passphrase: passphrase,
            ),
          );
          expect(restored.secret.id, secret.id);
          expect(restored.secret.info.language, language);
          expect(restored.metadata, {'label': 'published vector'});
          expect(
            ok(
              await restored.secret.verify.seed(
                convert.hex.encode(reference.seed),
              ),
            ),
            isTrue,
          );
          if (passphrase.isEmpty) expect(inspected, secret.id);
          final raw = Map<String, String>.of(storage.entries);
          final again = ok(
            await secrets.recoverbull.restore(
              vault: backup.vault,
              key: backup.key,
              passphrase: passphrase,
            ),
          );
          expect(again.secret.id, secret.id);
          expect(storage.entries, raw);
        },
      );
    }
  }

  test(
    'both reserved plaintext keys belong to the vault, never caller metadata',
    () async {
      final secret = ok(
        await secrets.import(words: [...List.filled(11, 'abandon'), 'about']),
      );
      for (final key in ['mnemonic', 'mnemonicLanguage']) {
        await expectLater(
          secret.backup.recoverbull(metadata: {key: 'override'}),
          throwsA(
            isA<ArgumentError>()
                .having((error) => error.invalidValue, 'invalidValue', key)
                .having((error) => error.name, 'name', 'metadata'),
          ),
        );
      }
    },
  );

  for (final reservedKey in ['mnemonic', 'mnemonicLanguage']) {
    test('caller mutation cannot inject $reservedKey while sealing', () async {
      final secret = ok(
        await secrets.import(words: [...List.filled(11, 'abandon'), 'about']),
      );
      final metadata = <String, dynamic>{'label': 'published vector'};
      final sealing = secret.backup.recoverbull(metadata: metadata);
      metadata[reservedKey] = reservedKey == 'mnemonic'
          ? ['override']
          : 'japanese';
      final backup = ok(await sealing);
      expect(
        ok(
          await secrets.recoverbull.fingerprint(
            vault: backup.vault,
            key: backup.key,
          ),
        ),
        secret.id,
      );
    });
  }

  test('unknown and null plaintext languages fail closed', () async {
    for (final language in ['unknown', null, 42]) {
      final file = RecoverBull.createBackup(
        secret: utf8.encode(
          jsonEncode({
            'mnemonic': [...List.filled(11, 'abandon'), 'about'],
            'mnemonicLanguage': language,
          }),
        ),
        backupKey: List<int>.filled(32, 0),
      ).toJson();
      final vault = EncryptedVault(json: file);
      final key = VaultKey('00' * 32);
      expect(
        err(await secrets.recoverbull.restore(vault: vault, key: key)),
        isA<InvalidVaultFailure>(),
      );
      expect(
        err(await secrets.recoverbull.fingerprint(vault: vault, key: key)),
        isA<InvalidVaultFailure>(),
      );
      expect(storage.entries, isEmpty);
    }
  });

  test(
    'caller language metadata stays free and round-trips untouched',
    () async {
      final secret = ok(
        await secrets.import(words: [...List.filled(11, 'abandon'), 'about']),
      );
      final backup = ok(
        await secret.backup.recoverbull(metadata: {'language': 'fr'}),
      );
      ok(await secrets.trash(secret.id));
      final restored = ok(
        await secrets.recoverbull.restore(vault: backup.vault, key: backup.key),
      );
      expect(restored.secret.id, secret.id);
      expect(restored.secret.info.language, bip39.Language.english);
      expect(restored.metadata, {'language': 'fr'});
    },
  );

  test('a vault predating languages keeps caller language metadata', () async {
    final english = [...List.filled(11, 'abandon'), 'about'];
    for (final callerValue in ['fr', 'japanese', null, 42]) {
      storage.entries.clear();
      final vault = EncryptedVault(
        json: RecoverBull.createBackup(
          secret: utf8.encode(
            jsonEncode({'language': callerValue, 'mnemonic': english}),
          ),
          backupKey: List<int>.filled(32, 0),
        ).toJson(),
      );
      final key = VaultKey('00' * 32);
      final restored = ok(
        await secrets.recoverbull.restore(vault: vault, key: key),
      );
      expect(restored.secret.info.language, bip39.Language.english);
      expect(restored.metadata, {'language': callerValue});
      expect(
        ok(await secrets.recoverbull.fingerprint(vault: vault, key: key)),
        restored.secret.id,
      );
    }
  });

  test(
    'restoring over an equivalent entry describes the entry it kept',
    () async {
      // Valid in both the English and the French wordlists. The seed derives from the sentence alone, so both readings are one secret.
      const shared = [
        'crucial', 'million', 'voyage', 'sentence', 'mobile', 'suspect', //
        'double', 'minute', 'virus', 'noble', 'junior', 'wagon',
      ];
      final french = ok(
        await secrets.import(words: shared, language: bip39.Language.french),
      );
      final raw = Map<String, String>.of(storage.entries);
      final vault = EncryptedVault(
        json: RecoverBull.createBackup(
          secret: utf8.encode(jsonEncode({'mnemonic': shared})),
          backupKey: List<int>.filled(32, 0),
        ).toJson(),
      );
      final restored = ok(
        await secrets.recoverbull.restore(
          vault: vault,
          key: VaultKey('00' * 32),
        ),
      );
      expect(restored.secret.id, french.id);
      expect(restored.secret.info.language, bip39.Language.french);
      expect(storage.entries, raw);
    },
  );
}
