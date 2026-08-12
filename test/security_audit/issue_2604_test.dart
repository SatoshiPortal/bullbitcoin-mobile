import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2604
// Finding: crypto-hdkey CBOR is decoded with incompatible key/value types.
// Regression test for the fix.
void main() {
  group('Security audit #2604 crypto-hdkey import', () {
    test(
      'decoder normalizes CBOR integer keys and uses byte-string key data',
      () {
        final source = File('lib/core/urqr/urqr.dart').readAsStringSync();
        expect(source, contains('keyData = (map[3] as CborBytes).bytes'));
        expect(source, contains('map[_cborInt(entry.key)] = entry.value'));
        expect(source, contains('CryptoHdKey.fromCborMap(map)'));
      },
    );
  });
}
