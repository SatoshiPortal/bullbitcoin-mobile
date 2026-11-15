import 'dart:convert';

import 'package:unorm_dart/unorm_dart.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/models/secret_model.dart';

import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:secrets/src/crypto/crypto.dart';

import 'result_helpers.dart';

void main() {
  // Published bip32JP Japanese BIP39 vector, entropy 000000…0000.
  final words = [...List.filled(11, 'あいこくしん'), 'あおぞら'];
  const passphrase = 'メートルガバヴァぱばぐゞちぢ十人十色';
  const seedHex =
      'a262d6fb6122ecf45be09c50492b31f92e9beb7d9a845987a02cefda57a15f9c'
      '467a17872029a9e92299b5cbdf306e3a0ee620245cbd508959b6cb7ca637bd55';
  late FakeSecureStoragePlatform storage;
  late Secrets secrets;
  setUp(() {
    storage = FakeSecureStoragePlatform()..install();
    secrets = Secrets(scratchDirectory: () async => '/tmp');
  });

  test(
    'stored Japanese vector reads and verifies its reference seed',
    () async {
      final seed = Deriver.fingerprint.seed(
        words,
        language: bip39.Language.japanese,
        passphrase: passphrase,
      );
      final id = Deriver.fingerprint.fingerprint(seed);
      storage.entries['seed_${id.hex}'] = jsonEncode({
        'mnemonicWords': words,
        'passphrase': passphrase,
        'runtimeType': 'mnemonic',
        'language': 'japanese',
      });
      final secret = ok(await secrets.fetch(id));
      expect(ok(await secret.verify.seed(seedHex)), isTrue);
    },
  );

  test('imports the Japanese vector with NFKD words and passphrase', () async {
    final secret = ok(
      await secrets.import(
        words: words,
        language: bip39.Language.japanese,
        passphrase: passphrase,
      ),
    );
    expect(secret.info.language, bip39.Language.japanese);
    expect(ok(await secret.verify.seed(seedHex)), isTrue);
    expect(ok(await secret.verify.mnemonic(words.map(nfc).toList())), isTrue);
    expect(ok(await secret.verify.mnemonic(words.map(nfkd).toList())), isTrue);
    expect(
      ok(
        await secrets.contains(
          words: words,
          language: bip39.Language.japanese,
          passphrase: passphrase,
        ),
      ),
      isTrue,
    );
    final encoded = storage.entries.values.single;
    final json = jsonDecode(encoded) as Map<String, dynamic>;
    expect(json['language'], 'japanese');
    expect(json['mnemonicWords'], words.map(nfkd).toList());
    expect(
      err(
        await secrets.import(
          words: words.map(nfc).toList(),
          language: bip39.Language.japanese,
          passphrase: passphrase,
        ),
      ),
      isA<SecretAlreadyExistsFailure>(),
    );
    expect(storage.entries.values.single, encoded);
  });

  for (final language in bip39.Language.values) {
    for (final pass in ['', 'TREZOR']) {
      test(
        'round-trips ${language.name}, passphrase: ${pass.isNotEmpty}',
        () async {
          // Zero-entropy BIP39 vector; reference seed is computed independently by bip39_mnemonic.
          final reference = bip39.Mnemonic(
            List.filled(16, 0),
            language,
            passphrase: pass,
          );
          final secret = ok(
            await secrets.import(
              words: reference.words,
              language: language,
              passphrase: pass,
            ),
          );
          final fetched = ok(await secrets.fetch(secret.id));
          expect(fetched.info.language, language);
          expect(
            ok(
              await fetched.verify.seed(
                reference.seed
                    .map((b) => b.toRadixString(16).padLeft(2, '0'))
                    .join(),
              ),
            ),
            isTrue,
          );
          expect(
            ok(
              await secrets.contains(
                words: reference.words,
                language: language,
                passphrase: pass,
              ),
            ),
            isTrue,
          );
          final listed = ok(await secrets.list()).whereType<Secret>().single;
          expect(listed.info.language, language);
          final json =
              jsonDecode(storage.entries.values.single) as Map<String, dynamic>;
          expect(
            json.containsKey('language'),
            language != bip39.Language.english,
          );
          final preview = ok(
            await secrets.preview.bitcoinDescriptors(
              words: reference.words,
              language: language,
              passphrase: pass,
              network: BitcoinNetwork.mainnet,
              scriptTypes: {ScriptType.bip84},
            ),
          )[ScriptType.bip84];
          expect(
            ok(
              await fetched.derive.descriptors.bitcoin(
                network: BitcoinNetwork.mainnet,
                scriptType: ScriptType.bip84,
              ),
            ),
            preview,
          );
        },
      );
    }
  }

  test('canonical import preserves a legacy composed Japanese entry', () async {
    final seed = Deriver.fingerprint.seed(
      words,
      language: bip39.Language.japanese,
    );
    final id = Deriver.fingerprint.fingerprint(seed);
    final raw = jsonEncode({
      'mnemonicWords': words.map(nfc).toList(),
      'passphrase': null,
      'runtimeType': 'mnemonic',
      'language': 'japanese',
    });
    storage.entries['seed_${id.hex}'] = raw;
    expect(
      err(
        await secrets.import(
          words: words.map(nfkd).toList(),
          language: bip39.Language.japanese,
        ),
      ),
      isA<SecretAlreadyExistsFailure>(),
    );
    expect(storage.entries['seed_${id.hex}'], raw);
  });

  test(
    'shared Chinese words compare seeds across different wordlists',
    () async {
      final reference = bip39.Mnemonic(
        List.filled(16, 0),
        bip39.Language.simplifiedChinese,
      );
      final secret = ok(
        await secrets.import(
          words: reference.words,
          language: bip39.Language.simplifiedChinese,
        ),
      );
      final raw = storage.entries['seed_${secret.id.hex}'];
      expect(
        err(
          await secrets.import(
            words: reference.words,
            language: bip39.Language.traditionalChinese,
          ),
        ),
        isA<SecretAlreadyExistsFailure>(),
      );
      expect(storage.entries['seed_${secret.id.hex}'], raw);
    },
  );

  test(
    'unknown or null stored language fails closed without rewriting',
    () async {
      final english = [...List.filled(11, 'abandon'), 'about'];
      final id = Fingerprint('73c5da0a');
      for (final language in ['unknown', null, 1]) {
        final raw = jsonEncode({
          'mnemonicWords': english,
          'passphrase': null,
          'runtimeType': 'mnemonic',
          'language': language,
        });
        storage.entries['seed_${id.hex}'] = raw;
        expect(err(await secrets.fetch(id)), isA<FetchSecretFailure>());
        expect(ok(await secrets.list()).single, isA<UnreadableSecret>());
        expect(storage.entries['seed_${id.hex}'], raw);
      }
    },
  );

  test('English fixtures re-encode byte for byte with no language key', () {
    for (final pass in [null, '', 'TREZOR']) {
      final raw = jsonEncode({
        'mnemonicWords': [...List.filled(11, 'abandon'), 'about'],
        'passphrase': pass,
        'runtimeType': 'mnemonic',
      });
      expect(
        jsonEncode(
          SecretModel.fromJson(jsonDecode(raw) as Map<String, dynamic>)
              .toJson(),
        ),
        raw,
      );
    }
  });
}
