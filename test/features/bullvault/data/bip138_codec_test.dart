import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bb_mobile/features/bullvault/data/bip138_codec.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup_key.dart';
import 'package:bip32_keys/bip32_keys.dart';
import 'package:bs58check/bs58check.dart' as base58;
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final vectors =
      jsonDecode(
            File(
              'test/features/bullvault/data/fixtures/bip138/encrypted_backup.json',
            ).readAsStringSync(),
          )
          as List;
  final codec = Bip138Codec();
  for (final vector in vectors.cast<Map<String, dynamic>>()) {
    test('pinned BIP138 vector: ${vector['description']}', () {
      for (final key in (vector['keys'] as List).cast<String>()) {
        final bytes = Uint8List.fromList(
          hex.decode(vector['expected'] as String),
        );
        final root = Uint8List.fromList(hex.decode(key).sublist(1));
        if (vector['valid'] == false) {
          expect(() => codec.decode(bytes, root), throwsFormatException);
        } else {
          final expected = vector['content'] == '01017c'
              ? [vector['plaintext']]
              : <String>[];
          expect(codec.decode(bytes, root), expected);
          final trailing = vector['trailing'];
          if (trailing is String) {
            expect(
              codec.decode(
                Uint8List.fromList([...bytes, ...hex.decode(trailing)]),
                root,
              ),
              expected,
            );
          }
        }
      }
    });
  }

  final keys = List.generate(
    3,
    (i) => DescriptorBackupKey.parse(
      Bip32Keys.fromSeed(
        Uint8List.fromList(List.filled(32, i + 1)),
      ).derivePath("m/48'/0'/0'/2'").neutered.toBase58(),
    ),
  );
  final descriptor =
      'wsh(sortedmulti(2,${keys.map((key) => '${key.xpub}/<0;1>/*').join(',')}))';

  test('every eligible recipient decodes the same standard artifact', () {
    final bytes = codec.encode(
      descriptor,
      keys.map((key) => key.xOnly).toList(),
    );
    for (var i = 0; i < keys.length; i++) {
      expect(codec.decode(bytes, keys[i].xOnly), [descriptor]);
      // The artifact never carries a recipient identity in the clear.
      expect(latin1.decode(bytes), isNot(contains(keys[i].xpub)));
    }
  });

  test(
    'header bounds, unknown encryption, tamper and wrong key fail closed',
    () {
      final bytes = codec.encode(
        descriptor,
        keys.map((key) => key.xOnly).toList(),
      );
      for (final length in [0, 6, 7, 8, 9, 100, bytes.length - 1]) {
        expect(
          () => codec.decode(
            Uint8List.sublistView(bytes, 0, length),
            keys.first.xOnly,
          ),
          throwsFormatException,
        );
      }
      final tampered = Uint8List.fromList(bytes)..[bytes.length - 1] ^= 1;
      expect(
        () => codec.decode(tampered, keys.first.xOnly),
        throwsFormatException,
      );
      expect(() => codec.decode(bytes, Uint8List(32)), throwsFormatException);
      expect(
        () => codec.decode(Uint8List(32769), keys.first.xOnly),
        throwsFormatException,
      );
    },
  );

  test(
    'equivalent public versions normalize; private keys and different chain codes do not',
    () {
      final bytes = base58.decode(keys.first.xpub);
      final alternate = Uint8List.fromList(bytes);
      ByteData.sublistView(alternate).setUint32(0, 0x04b24746);
      expect(
        DescriptorBackupKey.parse(
          base58.encode(alternate),
        ).sameAccount(keys.first),
        isTrue,
      );
      alternate[13] ^= 1;
      expect(
        DescriptorBackupKey.parse(
          base58.encode(alternate),
        ).sameAccount(keys.first),
        isFalse,
      );
      final privateKey = Bip32Keys.fromSeed(Uint8List(32)).toBase58();
      expect(
        () => DescriptorBackupKey.parse(privateKey),
        throwsFormatException,
      );
      expect(() => DescriptorBackupKey.parse('invalid'), throwsException);
    },
  );
}
