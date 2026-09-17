import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/src/data/models/secret_model.dart';

/// The on-disk format is a **frozen contract**.
///
/// These exact bytes are already on users' devices under
/// `seed_<fingerprint>`, written by the freezed union that used to live
/// in `core/seed/data/models/seed_model.dart`. Any drift orphans wallets
/// with no migration path short of asking the user for their backup.
///
/// So these tests pin the literal strings rather than round-tripping
/// through the model alone: a round-trip stays green even if both
/// directions drift together.
void main() {
  const words = [
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'about',
  ];

  const mnemonicJson =
      '{"mnemonicWords":["abandon","abandon","abandon","abandon","abandon",'
      '"abandon","abandon","abandon","abandon","abandon","abandon","about"],'
      '"passphrase":null,"runtimeType":"mnemonic"}';

  const passphraseJson =
      '{"mnemonicWords":["abandon","abandon","abandon","abandon","abandon",'
      '"abandon","abandon","abandon","abandon","abandon","abandon","about"],'
      '"passphrase":"TREZOR","runtimeType":"mnemonic"}';

  // Sixteen bytes: the shortest seed BIP32 accepts, and the shortest
  // entry the decoder does. A real entry has 16 to 64.
  const bytesJson =
      '{"bytes":[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,255],'
      '"runtimeType":"bytes"}';

  group('mnemonic entry', () {
    test('decodes the stored shape', () {
      final model =
          SecretModel.fromJson(jsonDecode(mnemonicJson) as Map<String, dynamic>)
              as MnemonicSecretModel;

      expect(model.mnemonicWords, words);
      expect(model.passphrase, isNull);
    });

    test('re-encodes to the exact same bytes', () {
      final model = SecretModel.fromJson(
        jsonDecode(mnemonicJson) as Map<String, dynamic>,
      );
      expect(jsonEncode(model.toJson()), mnemonicJson);
    });

    test('an absent passphrase stays null and never becomes ""', () {
      // Writing "" instead of null changes the stored bytes for every
      // passphrase-less wallet, which is the overwhelming majority.
      final model = SecretModel.fromJson(
        jsonDecode(mnemonicJson) as Map<String, dynamic>,
      );
      expect(model.toJson()['passphrase'], isNull);
      expect(
        MnemonicSecretModel(mnemonicWords: words).toJson()['passphrase'],
        isNull,
      );
    });

    test('a set passphrase survives the round trip', () {
      final model = SecretModel.fromJson(
        jsonDecode(passphraseJson) as Map<String, dynamic>,
      );
      expect((model as MnemonicSecretModel).passphrase, 'TREZOR');
      expect(jsonEncode(model.toJson()), passphraseJson);
    });

    test(
      'a missing passphrase key decodes as absent, and is written back canonically',
      () {
        // No writer ever produced this shape (`include_if_null: true`, always),
        // so it is a latitude the decoder grants, not a compatibility need.
        // Pinned so that tightening it is a deliberate, visible change.
        final absentKeyJson = mnemonicJson.replaceFirst(
          ',"passphrase":null',
          '',
        );
        expect(
          absentKeyJson,
          isNot(mnemonicJson),
          reason: 'the key was removed',
        );

        final model = SecretModel.fromJson(
          jsonDecode(absentKeyJson) as Map<String, dynamic>,
        );
        expect((model as MnemonicSecretModel).passphrase, isNull);
        expect(jsonEncode(model.toJson()), mnemonicJson);
      },
    );
  });

  group('bytes entry', () {
    test('decodes the stored shape', () {
      final model =
          SecretModel.fromJson(jsonDecode(bytesJson) as Map<String, dynamic>)
              as BytesSecretModel;
      expect(model.bytes, [
        0,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
        13,
        14,
        255,
      ]);
    });

    test('re-encodes to the exact same bytes', () {
      final model = SecretModel.fromJson(
        jsonDecode(bytesJson) as Map<String, dynamic>,
      );
      expect(jsonEncode(model.toJson()), bytesJson);
    });
  });

  group('key order is part of the contract', () {
    test('mnemonic keys keep their written order', () {
      expect(MnemonicSecretModel(mnemonicWords: words).toJson().keys.toList(), [
        'mnemonicWords',
        'passphrase',
        'runtimeType',
      ]);
    });

    test('bytes keys keep their written order', () {
      expect(
        BytesSecretModel(bytes: List.filled(16, 0)).toJson().keys.toList(),
        ['bytes', 'runtimeType'],
      );
    });
  });

  test('an unknown discriminator is rejected, not silently coerced', () {
    expect(
      () => SecretModel.fromJson({'runtimeType': 'descriptor'}),
      throwsFormatException,
    );
  });

  group('a corrupt entry is refused at decode, not at first use', () {
    // `List.cast` is lazy: before this was tightened, each of these
    // decoded without complaint and only threw when something read an
    // element — which meant a corrupt entry showed up in a listing as an
    // ordinary wallet and failed somewhere else entirely.
    test('words that are not strings', () {
      expect(
        () => SecretModel.fromJson(
          jsonDecode(
                '{"mnemonicWords":[1,2,3],"passphrase":null,'
                '"runtimeType":"mnemonic"}',
              )
              as Map<String, dynamic>,
        ),
        throwsFormatException,
      );
    });

    test('bytes that are not bytes', () {
      for (final bad in ['["aa"]', '[256]', '[-1]', '[null]']) {
        expect(
          () => SecretModel.fromJson(
            jsonDecode('{"bytes":$bad,"runtimeType":"bytes"}')
                as Map<String, dynamic>,
          ),
          throwsFormatException,
          reason: bad,
        );
      }
    });

    test('a missing field is a format error, not a type error', () {
      // The type matters: everything above this layer treats a
      // FormatException as "skip this entry", while a TypeError escapes
      // as an unexpected failure.
      expect(
        () => SecretModel.fromJson(
          jsonDecode('{"runtimeType":"mnemonic"}') as Map<String, dynamic>,
        ),
        throwsFormatException,
      );
      expect(
        () => SecretModel.fromJson(
          jsonDecode('{"runtimeType":"bytes"}') as Map<String, dynamic>,
        ),
        throwsFormatException,
      );
    });

    test('a passphrase of the wrong type', () {
      expect(
        () => SecretModel.fromJson(
          jsonDecode(
                '{"mnemonicWords":${jsonEncode(List.filled(12, 'abandon'))},'
                '"passphrase":42,"runtimeType":"mnemonic"}',
              )
              as Map<String, dynamic>,
        ),
        throwsFormatException,
      );
    });

    test('no discriminator at all', () {
      expect(() => SecretModel.fromJson(const {}), throwsFormatException);
    });

    test('the invariant belongs to the type, not to fromJson', () {
      // Built directly, not parsed: the check must still fire, or the
      // guarantee would hold on one code path only.
      expect(
        () => MnemonicSecretModel(mnemonicWords: const ['abandon']),
        throwsFormatException,
      );
      expect(
        () => BytesSecretModel(bytes: const [1, 2, 3]),
        throwsFormatException,
      );
    });

    test('a word count BIP39 does not define', () {
      // `[]` decoded into a wallet with no words before this check; a
      // 13-word list into one bip39 would refuse at first use. Both go
      // through bip39 on the way in, so neither was ever written.
      for (final count in [0, 1, 11, 13, 25]) {
        final list = jsonEncode(List.filled(count, 'abandon'));
        expect(
          () => SecretModel.fromJson(
            jsonDecode(
                  '{"mnemonicWords":$list,"passphrase":null,'
                  '"runtimeType":"mnemonic"}',
                )
                as Map<String, dynamic>,
          ),
          throwsFormatException,
          reason: '$count words',
        );
      }
    });

    test('a seed outside BIP32 bounds', () {
      for (final count in [0, 15, 65]) {
        final list = jsonEncode(List.filled(count, 7));
        expect(
          () => SecretModel.fromJson(
            jsonDecode('{"bytes":$list,"runtimeType":"bytes"}')
                as Map<String, dynamic>,
          ),
          throwsFormatException,
          reason: '$count bytes',
        );
      }
    });
  });

  group('an empty passphrase', () {
    // `store(passphrase: '')` derives the same identity as no passphrase
    // — so it overwrites the same entry, but writes `""` where the other
    // writes `null`. Two byte shapes for one secret; both must decode.
    const emptyJson =
        '{"mnemonicWords":["abandon","abandon","abandon","abandon","abandon",'
        '"abandon","abandon","abandon","abandon","abandon","abandon","about"],'
        '"passphrase":"","runtimeType":"mnemonic"}';

    test('decodes and re-encodes unchanged', () {
      final model = SecretModel.fromJson(
        jsonDecode(emptyJson) as Map<String, dynamic>,
      );
      expect((model as MnemonicSecretModel).passphrase, '');
      expect(jsonEncode(model.toJson()), emptyJson);
    });

    test('is not silently turned into null, nor null into it', () {
      final empty = SecretModel.fromJson(
        jsonDecode(emptyJson) as Map<String, dynamic>,
      );
      final absent = SecretModel.fromJson(
        jsonDecode(mnemonicJson) as Map<String, dynamic>,
      );
      expect((empty as MnemonicSecretModel).passphrase, '');
      expect((absent as MnemonicSecretModel).passphrase, isNull);
    });
  });
}
