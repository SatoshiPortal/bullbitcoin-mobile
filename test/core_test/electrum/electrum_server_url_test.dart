import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('with a scheme', () {
    const url = ElectrumServerUrl('tcp://electrum.example.com:50001');

    test('keeps the scheme and strips it from the authority', () {
      expect(url.scheme, 'tcp');
      expect(url.authority, 'electrum.example.com:50001');
      expect(url.uri?.host, 'electrum.example.com');
      expect(url.uri?.port, 50001);
    });
  });

  group('without a scheme', () {
    // Liquid servers are stored bare and are always TLS.
    const url = ElectrumServerUrl('blockstream.info:995');

    test('defaults to ssl and leaves the authority untouched', () {
      expect(url.scheme, 'ssl');
      expect(url.authority, 'blockstream.info:995');
      expect(url.uri?.scheme, 'ssl');
      expect(url.uri?.host, 'blockstream.info');
    });
  });

  group('isOnion', () {
    test('is true for an onion host, with or without a scheme', () {
      expect(const ElectrumServerUrl('abc.onion:50002').isOnion, isTrue);
      expect(const ElectrumServerUrl('ssl://abc.onion:50002').isOnion, isTrue);
    });

    test('is true for an absolute onion hostname', () {
      expect(const ElectrumServerUrl('abc.onion.:50002').isOnion, isTrue);
      expect(const ElectrumServerUrl('ssl://abc.onion.:50002').isOnion, isTrue);
    });

    test('is false for clearnet and for a host merely containing "onion"', () {
      expect(const ElectrumServerUrl('electrum.example.com').isOnion, isFalse);
      expect(const ElectrumServerUrl('onion.example.com:50002').isOnion, false);
    });
  });

  group('unusable addresses', () {
    // Custom servers are typed by hand: a blank one must not resolve to a
    // host, and the settings list still has to render it without crashing.
    test('expose no uri and are never onion', () {
      const blank = ElectrumServerUrl('   ');
      expect(blank.uri, isNull);
      expect(blank.isOnion, isFalse);
      expect(blank.authority, isEmpty);
    });

    test('tolerate surrounding whitespace around a real address', () {
      const padded = ElectrumServerUrl('  ssl://abc.onion:50002  ');
      expect(padded.isOnion, isTrue);
      expect(padded.authority, 'abc.onion:50002');
    });
  });
}
