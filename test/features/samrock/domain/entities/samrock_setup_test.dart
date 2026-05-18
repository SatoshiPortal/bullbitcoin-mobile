import 'package:bb_mobile/features/samrock/domain/entities/samrock_setup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SamrockSetupRequest.tryParse', () {
    test('parses valid SamRock URL with all methods', () {
      const url =
          'https://btcpay.example.com/plugins/abc123/samrock/protocol?setup=btc,lbtc,btcln&otp=token456';

      final result = SamrockSetupRequest.tryParse(url);

      expect(result, isNotNull);
      expect(result!.serverUrl, 'https://btcpay.example.com');
      expect(result.storeId, 'abc123');
      expect(result.otp, 'token456');
      expect(result.paymentMethods, [
        SamrockPaymentMethod.btc,
        SamrockPaymentMethod.lbtc,
        SamrockPaymentMethod.btcln,
      ]);
    });

    test('parses valid URL with only btc', () {
      const url =
          'https://server.com/plugins/store1/samrock/protocol?setup=btc&otp=abc';

      final result = SamrockSetupRequest.tryParse(url);

      expect(result, isNotNull);
      expect(result!.paymentMethods, [SamrockPaymentMethod.btc]);
    });

    test('parses valid URL with port', () {
      const url =
          'https://server.com:8443/plugins/store1/samrock/protocol?setup=lbtc&otp=abc';

      final result = SamrockSetupRequest.tryParse(url);

      expect(result, isNotNull);
      expect(result!.serverUrl, 'https://server.com:8443');
    });

    test('returns null for HTTP (non-HTTPS) URL', () {
      const url =
          'http://server.com/plugins/store1/samrock/protocol?setup=btc&otp=abc';

      final result = SamrockSetupRequest.tryParse(url);

      expect(result, isNull);
    });

    test('returns null for missing otp', () {
      const url =
          'https://server.com/plugins/store1/samrock/protocol?setup=btc';

      final result = SamrockSetupRequest.tryParse(url);

      expect(result, isNull);
    });

    test('returns null for missing setup param', () {
      const url =
          'https://server.com/plugins/store1/samrock/protocol?otp=abc';

      final result = SamrockSetupRequest.tryParse(url);

      expect(result, isNull);
    });

    test('returns null for wrong path', () {
      const url =
          'https://server.com/api/v1/samrock/protocol?setup=btc&otp=abc';

      final result = SamrockSetupRequest.tryParse(url);

      expect(result, isNull);
    });

    test('returns null for non-samrock path', () {
      const url =
          'https://server.com/plugins/store1/other/protocol?setup=btc&otp=abc';

      final result = SamrockSetupRequest.tryParse(url);

      expect(result, isNull);
    });

    test('returns null for unknown payment method', () {
      const url =
          'https://server.com/plugins/store1/samrock/protocol?setup=unknown&otp=abc';

      final result = SamrockSetupRequest.tryParse(url);

      expect(result, isNull);
    });

    test('returns null for empty string', () {
      final result = SamrockSetupRequest.tryParse('');
      expect(result, isNull);
    });

    test('returns null for random string', () {
      final result = SamrockSetupRequest.tryParse('not a url at all');
      expect(result, isNull);
    });

    test('generates correct setupUrl', () {
      const url =
          'https://btcpay.example.com/plugins/abc123/samrock/protocol?setup=btc,lbtc&otp=token456';

      final result = SamrockSetupRequest.tryParse(url);

      expect(result, isNotNull);
      expect(
        result!.setupUrl,
        'https://btcpay.example.com/plugins/abc123/samrock/protocol?setup=btc,lbtc&otp=token456',
      );
    });

    test('serverHost returns just the hostname', () {
      const url =
          'https://btcpay.example.com/plugins/abc123/samrock/protocol?setup=btc&otp=token';

      final result = SamrockSetupRequest.tryParse(url);

      expect(result!.serverHost, 'btcpay.example.com');
    });
  });

  group('SamrockPaymentMethod', () {
    test('fromString parses all valid methods', () {
      expect(SamrockPaymentMethod.fromString('btc'), SamrockPaymentMethod.btc);
      expect(
        SamrockPaymentMethod.fromString('lbtc'),
        SamrockPaymentMethod.lbtc,
      );
      expect(
        SamrockPaymentMethod.fromString('btcln'),
        SamrockPaymentMethod.btcln,
      );
    });

    test('fromString is case-insensitive', () {
      expect(SamrockPaymentMethod.fromString('BTC'), SamrockPaymentMethod.btc);
      expect(
        SamrockPaymentMethod.fromString('LBTC'),
        SamrockPaymentMethod.lbtc,
      );
      expect(
        SamrockPaymentMethod.fromString('BTCLN'),
        SamrockPaymentMethod.btcln,
      );
    });

    test('displayName returns correct strings', () {
      expect(
        SamrockPaymentMethod.btc.displayName,
        'Bitcoin On-chain',
      );
      expect(SamrockPaymentMethod.lbtc.displayName, 'Liquid');
      expect(
        SamrockPaymentMethod.btcln.displayName,
        'Lightning (via Boltz)',
      );
    });
  });
}
