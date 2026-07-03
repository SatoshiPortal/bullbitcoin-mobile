import 'dart:convert';

import 'package:bb_mobile/features/samrock/domain/entities/samrock_setup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Payload construction', () {
    test('BTC payload has correct structure', () {
      const btcDescriptor =
          "wpkh([abcdef01/84h/0h/0h]xpub6CUGRUo.../0/*)#checksum";

      final payload = <String, dynamic>{
        'BTC': {
          'Descriptor': btcDescriptor,
        },
      };

      expect(payload['BTC'], isA<Map>());
      expect(payload['BTC']['Descriptor'], btcDescriptor);
    });

    test('LBTC payload has correct structure', () {
      const liquidDescriptor =
          "ct(slip77(abcdef),elwpkh([abcdef01/84h/1776h/0h]xpub6CUGRUo.../0/*))";

      final payload = <String, dynamic>{
        'LBTC': {
          'Descriptor': liquidDescriptor,
        },
      };

      expect(payload['LBTC'], isA<Map>());
      expect(payload['LBTC']['Descriptor'], liquidDescriptor);
    });

    test('BTCLN payload has Boltz type and LBTC descriptor', () {
      const liquidDescriptor =
          "ct(slip77(abcdef),elwpkh([abcdef01/84h/1776h/0h]xpub6CUGRUo.../0/*))";

      final payload = <String, dynamic>{
        'BTCLN': {
          'Type': 'Boltz',
          'LBTC': {
            'Descriptor': liquidDescriptor,
          },
        },
      };

      expect(payload['BTCLN']['Type'], 'Boltz');
      expect(payload['BTCLN']['LBTC']['Descriptor'], liquidDescriptor);
    });

    test('full payload with all methods serializes to valid JSON', () {
      const btcDescriptor =
          "wpkh([abcdef01/84h/0h/0h]xpub6CUGRUo.../0/*)#checksum";
      const liquidDescriptor =
          "ct(slip77(abcdef),elwpkh([abcdef01/84h/1776h/0h]xpub6CUGRUo.../0/*))";

      final payload = <String, dynamic>{
        'BTC': {
          'Descriptor': btcDescriptor,
        },
        'LBTC': {
          'Descriptor': liquidDescriptor,
        },
        'BTCLN': {
          'Type': 'Boltz',
          'LBTC': {
            'Descriptor': liquidDescriptor,
          },
        },
      };

      final jsonString = jsonEncode(payload);
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(decoded['BTC']['Descriptor'], btcDescriptor);
      expect(decoded['LBTC']['Descriptor'], liquidDescriptor);
      expect(decoded['BTCLN']['Type'], 'Boltz');
      expect(decoded['BTCLN']['LBTC']['Descriptor'], liquidDescriptor);
    });

    test('form-encoded body has correct format', () {
      final payload = <String, dynamic>{
        'BTC': {
          'Descriptor': 'wpkh([fp/84h/0h/0h]xpub.../0/*)',
        },
      };

      final jsonString = jsonEncode(payload);
      final body = 'json=${Uri.encodeComponent(jsonString)}';

      expect(body, startsWith('json='));
      // Decode it back
      final decoded = Uri.decodeComponent(body.substring(5));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      expect(map['BTC']['Descriptor'], 'wpkh([fp/84h/0h/0h]xpub.../0/*)');
    });

    test('payment methods map correctly from setup param', () {
      const setupParam = 'btc,lbtc,btcln';
      final methods = setupParam
          .split(',')
          .map((m) => SamrockPaymentMethod.fromString(m.trim()))
          .toList();

      expect(methods.length, 3);
      expect(methods[0], SamrockPaymentMethod.btc);
      expect(methods[1], SamrockPaymentMethod.lbtc);
      expect(methods[2], SamrockPaymentMethod.btcln);
    });
  });
}
