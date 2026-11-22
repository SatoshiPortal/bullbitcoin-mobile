import 'package:bbx_api/bbx_api.dart';
import 'package:bbx_api/bbx_api_testing.dart';
import 'package:test/test.dart';

import 'fake_http.dart';
import 'result_helpers.dart';

Map<String, Object?> _summary() => {
  'userNumber': 42,
  'userId': 'u-1',
  'groups': ['KYC_IDENTITY_VERIFIED', 'JURI_EU'],
  'profile': {'firstName': 'Satoshi', 'lastName': 'Nakamoto'},
  'email': 'sat@example.com',
  'balances': [
    {'amount': 12, 'currencyCode': 'CAD'},
  ],
  'language': 'en',
  'currency': 'CAD',
  'dca': {
    'isActive': true,
    'frequency': 'Weekly',
    'amount': 100,
    'address': 'bc1q',
    'recipientType': 'OUT_BITCOIN_ADDRESS',
    'currencyCode': 'CAD',
  },
  'autoBuy': {
    'isActive': false,
    'addresses': {'bitcoin': 'bc1q', 'lightning': null},
  },
  'emailNotificationsEnabled': false,
  'payjoinReceiveEnabled': true,
  'kycDocumentStatus': {
    'secureFileUpload': 'UNDER_REVIEW',
    'documents': {'id': 'ACCEPTED'},
  },
};

void main() {
  group('getUserSummary', () {
    test('calls api-users and reads the result', () async {
      final http = FakeHttp(body: {'result': _summary()});
      final summary = valueOf(await bbx(http).users.getUserSummary());

      final request = http.requests.single;
      expect(request.path, '/ak/api-users');
      expect((request.data as Map)['method'], 'getUserSummary');
      expect((request.data as Map)['params'], isEmpty);

      if (summary == null) {
        fail('Expected a user summary');
      }
      expect(summary.userNumber, 42);
      expect(summary.userId, 'u-1');
      expect(summary.groups, ['KYC_IDENTITY_VERIFIED', 'JURI_EU']);
      expect(summary.profile.lastName, 'Nakamoto');
      expect(summary.email, 'sat@example.com');
      expect(summary.balances.single.amount, 12.0);
      expect(summary.balances.single.currencyCode, 'CAD');
      expect(summary.dca.frequency, 'Weekly');
      expect(summary.dca.amount, 100.0);
      expect(summary.dca.recipientType, 'OUT_BITCOIN_ADDRESS');
      expect(summary.autoBuy.addresses.bitcoin, 'bc1q');
      expect(summary.autoBuy.addresses.lightning, isNull);
      expect(summary.emailNotificationsEnabled, isFalse);
      expect(summary.payjoinReceiveEnabled, isTrue);
      final kyc =
          summary.kycDocumentStatus ?? fail('Expected KYC document status');
      expect(kyc.secureFileUpload, 'UNDER_REVIEW');
      expect(kyc.documents.id, 'ACCEPTED');
      expect(kyc.documents.selfie, 'NOT_UPLOADED');
    });

    test('defaults for omitted optional fields', () async {
      final body = _summary()
        ..remove('emailNotificationsEnabled')
        ..remove('payjoinReceiveEnabled')
        ..remove('kycDocumentStatus');
      final summary = valueOf(
        await bbx(FakeHttp(body: {'result': body})).users.getUserSummary(),
      );

      if (summary == null) {
        fail('Expected a user summary with optional fields omitted');
      }
      expect(summary.emailNotificationsEnabled, isTrue);
      expect(summary.payjoinReceiveEnabled, isFalse);
      expect(summary.kycDocumentStatus, isNull);
    });

    test('no result is null', () async {
      final summary = valueOf(
        await bbx(FakeHttp(body: {'result': null})).users.getUserSummary(),
      );
      expect(summary, isNull);
    });

    for (final field in ['userNumber', 'groups', 'profile', 'email', 'dca']) {
      test('a missing $field is a format failure', () async {
        final body = _summary()..remove(field);
        expect(
          await failedCall(
            bbx(FakeHttp(body: {'result': body})).users.getUserSummary(),
          ),
          isA<BbxResponseFormatFailure>(),
        );
      });
    }

    test('a result that is not an object is a format failure', () async {
      expect(
        await failedCall(
          bbx(FakeHttp(body: {'result': 'x'})).users.getUserSummary(),
        ),
        isA<BbxResponseFormatFailure>(),
      );
    });
  });

  group('registerResponsibilityConsent', () {
    test('sends the method and reads success', () async {
      final http = FakeHttp(
        body: {
          'result': {'success': true},
        },
      );
      expect(
        valueOf(await bbx(http).users.registerResponsibilityConsent()),
        isTrue,
      );

      final request = http.requests.single;
      expect(request.path, '/ak/api-users');
      expect((request.data as Map)['method'], 'registerResponsibilityConsent');
    });

    for (final result in [
      null,
      {'success': false},
      <String, Object?>{},
      true,
      'ok',
    ]) {
      test('$result is not a success', () async {
        expect(
          valueOf(
            await bbx(FakeHttp(body: {'result': result})).users
                .registerResponsibilityConsent(),
          ),
          isFalse,
        );
      });
    }
  });

  group('saveUserPreferences', () {
    test('sends only the given preferences under their wire keys', () async {
      final http = FakeHttp(body: {'result': null});
      valueOf(
        await bbx(http).users.saveUserPreferences(
          const UserPreferences(
            language: 'en',
            dcaEnabled: 'true',
            emailNotifications: 'false',
          ),
        ),
      );

      final request = http.requests.single;
      expect(request.path, '/ak/api-users');
      expect((request.data as Map)['method'], 'saveUserPreferences');
      expect((request.data as Map)['params'], {
        'userPreferences': {
          'LANGUAGE': 'en',
          'DCA_ENABLED': 'true',
          'EMAIL_NOTIFICATIONS': 'false',
        },
      });
    });

    test('all preferences', () {
      expect(
        userPreferencesJsonForTesting(
          const UserPreferences(
            language: 'fr',
            defaultFiatCurrencyCode: 'EUR',
            dcaEnabled: 'false',
            autoBuyEnabled: 'true',
            emailNotifications: 'true',
          ),
        ),
        {
          'LANGUAGE': 'fr',
          'DEFAULT_FIAT_CURRENCY_CODE': 'EUR',
          'DCA_ENABLED': 'false',
          'AUTO_BUY_ENABLED': 'true',
          'EMAIL_NOTIFICATIONS': 'true',
        },
      );
    });

    test('a JSON-RPC error is a failure', () async {
      expect(
        await failedCall(
          bbx(
            FakeHttp(
              body: {
                'error': {'code': 1, 'message': 'no'},
              },
            ),
          ).users.saveUserPreferences(const UserPreferences(language: 'en')),
        ),
        isA<BbxRpcFailure>()
            .having((f) => f.code, 'code', 1)
            .having((f) => f.message, 'message', 'no'),
      );
    });
  });
}
