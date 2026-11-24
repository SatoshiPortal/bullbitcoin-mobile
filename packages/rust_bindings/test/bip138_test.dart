import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rust_bindings/rust_bindings.dart';

// Public keys from the official vectors encoded as xpubs with zero chain code.
// No seed or private key is involved; decryption uses the xpub root itself.
const _candidates = <String, String>{
  '02e6642fd69bd211f93f7f1f36ca51a26a5290eb2dd1b0d8279a87bb0d480c8443': 'wpkh(xpub661MyMwAqRbcEYS8w7XLSVeEsBXy79zSzH1J8vCdxAZningWLdN3zgtU6RpmZnd4aqWHHnM5UyKSsvyBgU61Xo1DJ8wYJfuTHfCzDdfJhT4)',
  '02ee3887104834ec2970bb793abc7fd37661e2c44c49fb48c10745ef7d7c85b17c': 'wpkh(xpub661MyMwAqRbcEYS8w7XLSVeEsBXy79zSzH1J8vCdxAZningWLdN3zgtU6RtDZNtN4AkYSStEGCG5bWSUJ9z2NUNanQjqfPbsFmzcnAFoVsb)',
  '036f155ae2153b09bb4e1383756723c0879e80d0f32767c7e4875d5de2fb9a400d': 'wpkh(xpub661MyMwAqRbcEYS8w7XLSVeEsBXy79zSzH1J8vCdxAZningWLdN3zgtU6SryBUTg3H1zwZpjHKE7pwDSzQVUWQBUQhzZxxwtwBagJrN3KWU)',
  '0384526253c27c7aef56c7b71a5cd25bebb66dddda437826defc5b2568bde81f07': 'wpkh(xpub661MyMwAqRbcEYS8w7XLSVeEsBXy79zSzH1J8vCdxAZningWLdN3zgtU6T2KgqdA6kYsoFr2xYaZidoy7EciT7rjkN3HT3ggbv2ia5VMEr2)',
  '03c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5': 'wpkh(xpub661MyMwAqRbcEYS8w7XLSVeEsBXy79zSzH1J8vCdxAZningWLdN3zgtU6TXFoDctwnBD5YZJpHMHro16HV57ZmaRes23a61shPQFLdjQu3U)',
};
const _descriptor =
    'wpkh([d34db33f/84h/1h/0h]tpubDC5FSnBiZDMmhiuCmWAYsLwgLYrrT9rAqvTySfuCCrgsWz8wxMXUS9Tb9iVMvcRbvFcAHGkMD5Kx8koh4GquNGNTfohfk7pgjhaPCdXpoba/0/*)';

Uint8List _hex(String value) => Uint8List.fromList([
  for (var i = 0; i < value.length; i += 2)
    int.parse(value.substring(i, i + 2), radix: 16),
]);

void main() {
  setUpAll(BullSdk.init);

  test('official encrypted_backup vectors decrypt through FRB', () async {
    final vectors = jsonDecode(
      File('rust/crates/dart_bip138/tests/vectors/encrypted_backup.json')
          .readAsStringSync(),
    ) as List<dynamic>;
    for (final row in vectors.cast<Map<String, dynamic>>()) {
      final key = (row['keys'] as List<dynamic>).first as String;
      final candidate = _candidates[key];
      expect(candidate, isNotNull);
      if (candidate == null) continue;
      final encoded = _hex(row['expected'] as String);
      if (row['valid'] == false) {
        await expectLater(
          bip138Decrypt(
            bytes: encoded,
            candidatePublicDescriptors: [candidate],
          ),
          throwsA(isA<Bip138Error>()),
        );
        continue;
      }
      final items = await bip138Decrypt(
        bytes: encoded,
        candidatePublicDescriptors: [candidate],
      );
      final expected = <String>[
        row['plaintext'] as String,
        for (final extra in (row['extra'] as List<dynamic>? ?? []))
          (extra as Map<String, dynamic>)['plaintext'] as String,
      ];
      expect(
        items?.map((item) => utf8.decode(item.bytes)),
        expected,
        reason: row['description'] as String,
      );
    }
  });

  test('BIP139 and vendor items round-trip with geometric padding', () async {
    final document = utf8.encode(
      jsonEncode({
        'version': 'BIP139-1',
        'network': 'regtest',
        'accounts': [
          {
            'type': 'multi_bip380',
            'descriptor': [_descriptor],
          },
        ],
      }),
    );
    final items = [
      Bip138Item(
        contentType: const Bip138ContentType.bip(number: 139),
        bytes: Uint8List.fromList(document),
      ),
      Bip138Item(
        contentType: Bip138ContentType.vendor(
          tag: Uint8List.fromList(utf8.encode('bull')),
        ),
        bytes: Uint8List.fromList(utf8.encode('{"v":1}')),
      ),
    ];
    final encrypted = await bip138Encrypt(
      publicDescriptors: [_descriptor],
      items: items,
      padded: true,
    );
    final recovered = await bip138Decrypt(
      bytes: encrypted,
      candidatePublicDescriptors: [_descriptor],
    );
    expect(
      recovered?.map((item) => item.bytes),
      items.map((item) => item.bytes),
    );
    expect(
      recovered?.map((item) => item.contentType),
      items.map((item) => item.contentType),
    );
    await expectLater(
      bip138Encrypt(
        publicDescriptors: [_descriptor.replaceAll('/0/*', '/1/*')],
        items: items,
        padded: true,
      ),
      throwsA(isA<Bip138Error>()),
    );
    final unrelated = _candidates.values.first;
    expect(
      await bip138Decrypt(
        bytes: encrypted,
        candidatePublicDescriptors: [unrelated],
      ),
      isNull,
    );
  });

  test(
    'garbage, wrong magic, truncated and huge counts fail through FRB',
    () async {
      for (final bytes in [
        <int>[],
        utf8.encode('garbage'),
        utf8.encode('BIP139'),
        [...utf8.encode('BIP138'), 1],
        [...utf8.encode('BIP138'), 1, 255, 255],
        List<int>.filled(4 * 1024 * 1024 + 1, 0),
      ]) {
        await expectLater(
          bip138Decrypt(
            bytes: Uint8List.fromList(bytes),
            candidatePublicDescriptors: [_descriptor],
          ),
          throwsA(isA<Bip138Error>()),
        );
      }
    },
  );
}
