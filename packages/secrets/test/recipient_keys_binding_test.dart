import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rust_bindings/rust_bindings.dart';
import 'package:secrets/src/data/inventory_repository.dart' show recipientKeys;

// The BIP138 test vector's tpub and the BIP32 vector's xpub.
const _a =
    'tpubDC5FSnBiZDMmhiuCmWAYsLwgLYrrT9rAqvTySfuCCrgsWz8wxMXUS9Tb9iVMvcRbvFcAHGkMD5Kx8koh4GquNGNTfohfk7pgjhaPCdXpoba';
const _b =
    'xpub661MyMwAqRbcEYS8w7XLSVeEsBXy79zSzH1J8vCdxAZningWLdN3zgtU6RpmZnd4aqWHHnM5UyKSsvyBgU61Xo1DJ8wYJfuTHfCzDdfJhT4';

String _wpkh(String key, String path) => "wpkh([01234567/84'/1'/0']$key/$path)";
String _shWpkh(String key, String path) =>
    "sh(wpkh([01234567/49'/1'/0']$key/$path))";
String _pkh(String key, String path) => "pkh([01234567/44'/1'/0']$key/$path)";

Future<Uint8List> _encryptTo(String descriptor) => bip138Encrypt(
  publicDescriptors: [descriptor],
  items: [
    Bip138Item(
      contentType: const Bip138ContentType.bip(number: 139),
      bytes: Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'version': 'BIP139-1',
            'network': 'testnet',
            'accounts': [
              {
                'type': 'multi_bip380',
                'descriptor': [descriptor],
              },
            ],
          }),
        ),
      ),
    ),
  ],
  padded: true,
);

void main() {
  setUpAll(BullSdk.init);

  // For every supported form, whether the native binding lets a descriptor
  // open a file is exactly whether Secrets extracts the same recipient keys.
  final forms = <String, String Function(String, String)>{
    'wpkh': _wpkh,
    'sh(wpkh)': _shWpkh,
    'pkh': _pkh,
  };
  for (final writer in forms.entries) {
    for (final reader in forms.entries) {
      for (final sameKey in [true, false]) {
        test('${writer.key} file read through ${reader.key}, '
            '${sameKey ? 'same' : 'other'} key', () async {
          final written = writer.value(_a, '0/*');
          final candidate = reader.value(sameKey ? _a : _b, '1/*');
          final opened = await bip138Decrypt(
            bytes: await _encryptTo(written),
            candidatePublicDescriptors: [candidate],
          );
          final shared = recipientKeys(written)
              .intersection(recipientKeys(candidate));
          expect(recipientKeys(written), isNotEmpty);
          expect(
            shared.isNotEmpty,
            opened != null,
            reason: 'Secrets and the binding must agree on who can decrypt',
          );
          expect(sameKey, opened != null);
        });
      }
    }
  }
}
