import 'package:bb_mobile/core/exchange/data/datasources/http/bullbitcoin_api_dio_factory.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_auth_navigation_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exposes the configured build-time Bull Bitcoin origins', () {
    expect(
      ApiServiceConstants.bbApiUrl,
      const String.fromEnvironment(
        'BB_API_BASE_URL',
        defaultValue: 'https://api.bullbitcoin.com',
      ),
    );
    expect(
      ApiServiceConstants.bbAuthUrl,
      const String.fromEnvironment(
        'BB_AUTH_BASE_URL',
        defaultValue: 'https://accounts.bullbitcoin.com',
      ),
    );
    expect(
      ApiServiceConstants.bbApiTestUrl,
      const String.fromEnvironment(
        'BB_API_TEST_BASE_URL',
        defaultValue: 'https://api05.bullbitcoin.dev',
      ),
    );
    expect(
      ApiServiceConstants.bbAuthTestUrl,
      const String.fromEnvironment(
        'BB_AUTH_TEST_BASE_URL',
        defaultValue: 'https://accounts05.bullbitcoin.dev',
      ),
    );
  });

  test('selects the configured API origin for each network', () {
    expect(
      BullBitcoinApiDioFactory.create(isTestnet: false).options.baseUrl,
      ApiServiceConstants.bbApiUrl,
    );
    expect(
      BullBitcoinApiDioFactory.create(isTestnet: true).options.baseUrl,
      ApiServiceConstants.bbApiTestUrl,
    );
  });

  group('validateHttpsOrigin', () {
    test('accepts and normalizes an HTTPS origin', () {
      expect(
        validateHttpsOrigin(
          'https://staging-vibe-bbx.bull-wallet.com/',
          configurationName: 'test',
        ),
        'https://staging-vibe-bbx.bull-wallet.com',
      );
    });

    test('accepts an explicit HTTPS port', () {
      expect(
        validateHttpsOrigin(
          'https://localhost.example:8443',
          configurationName: 'test',
        ),
        'https://localhost.example:8443',
      );
    });

    for (final invalid in [
      'http://staging.example',
      'https://',
      'https://user:password@staging.example',
      'https://staging.example/api',
      'https://staging.example?lane=fiat',
      'https://staging.example#fiat',
      ' https://staging.example',
    ]) {
      test('rejects $invalid', () {
        expect(
          () => validateHttpsOrigin(invalid, configurationName: 'test'),
          throwsFormatException,
        );
      });
    }
  });

  group('exchange auth navigation', () {
    const authOrigin = 'https://staging-vibe.bull-wallet.com';

    test('allows every path on the configured auth origin', () {
      expect(
        isAllowedExchangeAuthNavigation(
          requestUrl: '$authOrigin/registration?flow=123',
          authBaseUrl: authOrigin,
        ),
        isTrue,
      );
    });

    test('rejects a lookalike auth host', () {
      expect(
        isAllowedExchangeAuthNavigation(
          requestUrl: 'https://staging-vibe.bull-wallet.com.attacker.test/',
          authBaseUrl: authOrigin,
        ),
        isFalse,
      );
    });

    test('rejects malformed and credential-bearing URLs', () {
      expect(
        isAllowedExchangeAuthNavigation(
          requestUrl: 'https:',
          authBaseUrl: authOrigin,
        ),
        isFalse,
      );
      expect(
        isAllowedExchangeAuthNavigation(
          requestUrl: 'https://user@staging-vibe.bull-wallet.com/registration',
          authBaseUrl: authOrigin,
        ),
        isFalse,
      );
    });

    test('allows only terms and privacy paths on the public website', () {
      expect(
        isAllowedExchangeAuthNavigation(
          requestUrl: 'https://www.bullbitcoin.com/legal/privacy',
          authBaseUrl: authOrigin,
        ),
        isTrue,
      );
      expect(
        isAllowedExchangeAuthNavigation(
          requestUrl: 'https://www.bullbitcoin.com/',
          authBaseUrl: authOrigin,
        ),
        isFalse,
      );
      expect(
        isAllowedExchangeAuthNavigation(
          requestUrl: 'https://www.bullbitcoin.com.attacker.test/privacy',
          authBaseUrl: authOrigin,
        ),
        isFalse,
      );
    });
  });
}
