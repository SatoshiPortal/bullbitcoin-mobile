import 'package:exchange/exchange.dart';
import 'package:bbx_api/bbx_api.dart' show BbxCredentialUnavailableFailure;
import 'package:exchange/src/data/bbx_api_user_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'bbx_api_test_http.dart';

F _failureOf<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok() => fail('expected an Err, got Ok'),
  Err(:final failure) => failure,
};

T _valueOf<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('expected an Ok, got ${failure.runtimeType}'),
};

const _summary = {
  'userNumber': 42,
  'userId': 'u-1',
  'groups': ['KYC_IDENTITY_VERIFIED', 'CONSENT_SCAM_WARNING'],
  'profile': {'firstName': 'Satoshi', 'lastName': 'Nakamoto'},
  'email': 'sat@example.com',
  'balances': [
    {'amount': 12.5, 'currencyCode': 'CAD'},
  ],
  'language': 'en',
  'currency': 'CAD',
  'dca': {
    'isActive': true,
    'frequency': 'Weekly',
    'amount': 100,
    'address': 'bc1qdca',
    'recipientType': 'OUT_LIGHTNING_ADDRESS',
    'currencyCode': 'XXX',
  },
  'autoBuy': {
    'isActive': true,
    'addresses': {'liquid': 'lq1'},
  },
  'payjoinReceiveEnabled': true,
  'kycDocumentStatus': {
    'secureFileUpload': 'under_review',
    'documents': {'id': 'ACCEPTED', 'selfie': 'REJECTED'},
  },
};

const _rpcError = {
  'error': {'code': -1, 'message': 'rejected for sat@example.com'},
};

BbxApiUserRepository _repository(FakeBbxHttp http) =>
    BbxApiUserRepository(api: http.client());

BbxApiUserRepository _signedOut(FakeBbxHttp http) => BbxApiUserRepository(
  api: http.client(readApiKey: () async => const Ok(null)),
);

BbxApiUserRepository _unreadableKey(FakeBbxHttp http) => BbxApiUserRepository(
  api: http.client(
    readApiKey: () async => const Err(BbxCredentialUnavailableFailure()),
  ),
);

void main() {
  group('getUserSummary', () {
    test('maps the bbx_api summary to the entity', () async {
      final summary = _valueOf(
        await _repository(FakeBbxHttp(body: {'result': _summary}))
            .getUserSummary(),
      );

      expect(summary.userNumber, 42);
      expect(summary.userId, 'u-1');
      expect(summary.hasConsentedScamWarning, isTrue);
      expect(summary.isFullyVerifiedKycLevel, isTrue);
      expect(
        summary.profile,
        const UserProfile(firstName: 'Satoshi', lastName: 'Nakamoto'),
      );
      expect(summary.balances, const [
        UserBalance(amount: 12.5, currencyCode: 'CAD'),
      ]);
      expect(summary.language, 'en');
      expect(summary.currency, 'CAD');
      expect(
        summary.dca,
        const UserDca(
          isActive: true,
          frequency: DcaBuyFrequency.weekly,
          amount: 100,
          network: BtcNetwork.lightning,
          address: 'bc1qdca',
        ),
      );
      expect(summary.autoBuy.isActive, isTrue);
      expect(summary.autoBuy.addresses.liquid, 'lq1');
      expect(summary.emailNotificationsEnabled, isTrue);
      expect(summary.payjoinReceiveEnabled, isTrue);
      expect(
        summary.kycDocumentStatus,
        const UserKycDocumentStatus(
          secureFileUpload: KycDocumentStatus.underReview,
          documents: UserKycDocuments(
            id: KycDocumentStatus.accepted,
            proofOfResidence: KycDocumentStatus.notUploaded,
            selfie: KycDocumentStatus.rejected,
          ),
        ),
      );
    });

    test('a supported DCA currency is kept', () async {
      final body = {
        ..._summary,
        'dca': {'isActive': false, 'currencyCode': 'CAD'},
      };
      final summary = _valueOf(
        await _repository(FakeBbxHttp(body: {'result': body})).getUserSummary(),
      );
      expect(summary.dca.currency, FiatCurrency.cad);
      expect(summary.dca.frequency, isNull);
      expect(summary.dca.network, isNull);
    });

    test('a JSON-RPC error reply is an unavailable summary, not a sign-out '
        '(INT-8)', () async {
      expect(
        _failureOf(
          await _repository(FakeBbxHttp(body: _rpcError)).getUserSummary(),
        ),
        isA<ExchangeAccountUnavailableFailure>(),
      );
    });

    test('an empty answer is an unavailable summary, as for the account '
        '(INT-8)', () async {
      expect(
        _failureOf(
          await _repository(FakeBbxHttp(body: {'result': null}))
              .getUserSummary(),
        ),
        isA<ExchangeAccountUnavailableFailure>(),
      );
    });

    test('an HTTP 401 is a rejected session', () async {
      expect(
        _failureOf(
          await _repository(FakeBbxHttp(status: 401, body: const {}))
              .getUserSummary(),
        ),
        isA<ExchangeSessionRejectedFailure>(),
      );
    });

    test('no stored key is not-authenticated, without a request', () async {
      final http = FakeBbxHttp(body: {'result': _summary});
      expect(
        _failureOf(await _signedOut(http).getUserSummary()),
        isA<ExchangeNotAuthenticatedFailure>(),
      );
      expect(http.requests, isEmpty);
    });

    test('an unreadable key is a credential failure', () async {
      final http = FakeBbxHttp(body: {'result': _summary});
      expect(
        _failureOf(await _unreadableKey(http).getUserSummary()),
        isA<ExchangeCredentialReadFailure>(),
      );
      expect(http.requests, isEmpty);
    });

    test('a connection error is a network failure', () async {
      final failure = _failureOf(
        await _repository(FakeBbxHttp(error: DioExceptionType.connectionError))
            .getUserSummary(),
      );
      expect(failure, isA<ExchangeNetworkFailure>());
      expect(failure.logMessage, startsWith('getUserSummary unreachable: '));
    });

    test('an HTTP error is not a connection problem', () async {
      expect(
        _failureOf(
          await _repository(FakeBbxHttp(status: 503, body: const {}))
              .getUserSummary(),
        ),
        isA<ExchangeAccountUnavailableFailure>(),
      );
    });

    test('a malformed summary is a sanitized failure', () async {
      final failure = _failureOf(
        await _repository(
          FakeBbxHttp(
            body: {
              'result': {..._summary, 'email': null},
            },
          ),
        ).getUserSummary(),
      );
      expect(failure, isA<ExchangeAccountUnavailableFailure>());
      expect(
        failure.logMessage,
        startsWith('getUserSummary failed: BbxResponseFormatFailure'),
      );
    });
  });

  group('registerScamWarningConsent', () {
    test('a success is Ok', () async {
      final http = FakeBbxHttp(
        body: {
          'result': {'success': true},
        },
      );
      expect(
        await _repository(http).registerScamWarningConsent(),
        isA<Ok<void, ExchangeFailure>>(),
      );
      expect(
        (http.requests.single.data as Map)['method'],
        'registerResponsibilityConsent',
      );
    });

    test('no success flag is a consent failure', () async {
      expect(
        _failureOf(
          await _repository(
            FakeBbxHttp(
              body: {
                'result': {'success': false},
              },
            ),
          ).registerScamWarningConsent(),
        ),
        isA<ExchangeConsentRegistrationFailure>(),
      );
    });

    test('no stored key is not-authenticated', () async {
      expect(
        _failureOf(
          await _signedOut(FakeBbxHttp()).registerScamWarningConsent(),
        ),
        isA<ExchangeNotAuthenticatedFailure>(),
      );
    });
  });

  group('saveUserPreference', () {
    test('sends the preferences as the old client did', () async {
      final http = FakeBbxHttp(body: {'result': null});
      final result = await _repository(http).saveUserPreference(
        language: 'fr',
        currency: 'EUR',
        dcaEnabled: false,
        autoBuyEnabled: 'true',
        emailNotificationsEnabled: true,
      );

      expect(result, isA<Ok<void, ExchangeFailure>>());
      final request = http.requests.single;
      expect(request.path, '/ak/api-users');
      expect((request.data as Map)['method'], 'saveUserPreferences');
      expect((request.data as Map)['params'], {
        'userPreferences': {
          'LANGUAGE': 'fr',
          'DEFAULT_FIAT_CURRENCY_CODE': 'EUR',
          'DCA_ENABLED': 'false',
          'AUTO_BUY_ENABLED': 'true',
          'EMAIL_NOTIFICATIONS': 'true',
        },
      });
    });

    test('a JSON-RPC error is a sanitized save failure', () async {
      final failure = _failureOf(
        await _repository(FakeBbxHttp(body: _rpcError))
            .saveUserPreference(language: 'en'),
      );
      expect(failure, isA<ExchangePreferencesSaveFailure>());
      expect(failure.logMessage, isNot(contains('sat@example.com')));
    });

    for (final (name, http) in [
      ('a body that is not an object', FakeBbxHttp(body: 'unexpected')),
      (
        'a timeout after sending',
        FakeBbxHttp(error: DioExceptionType.receiveTimeout),
      ),
      ('a gateway timeout', FakeBbxHttp(status: 504, body: {})),
    ]) {
      test('$name is an unknown outcome', () async {
        expect(
          _failureOf(
            await _repository(http).saveUserPreference(autoBuyEnabled: 'true'),
          ),
          isA<ExchangePreferencesSaveOutcomeUnknownFailure>(),
        );
      });
    }

    test('a connect timeout is a network failure', () async {
      expect(
        _failureOf(
          await _repository(
            FakeBbxHttp(error: DioExceptionType.connectionTimeout),
          ).saveUserPreference(autoBuyEnabled: 'true'),
        ),
        isA<ExchangeNetworkFailure>(),
      );
    });

    for (final (name, http) in [
      ('a status other than 200', FakeBbxHttp(status: 500, body: {})),
    ]) {
      test('$name is a save failure', () async {
        expect(
          _failureOf(
            await _repository(http).saveUserPreference(autoBuyEnabled: 'true'),
          ),
          isA<ExchangePreferencesSaveFailure>(),
        );
      });
    }

    test('no stored key is not-authenticated', () async {
      expect(
        _failureOf(
          await _signedOut(FakeBbxHttp()).saveUserPreference(language: 'en'),
        ),
        isA<ExchangeNotAuthenticatedFailure>(),
      );
    });

    test('an unreadable key is a credential failure', () async {
      expect(
        _failureOf(
          await _unreadableKey(FakeBbxHttp())
              .saveUserPreference(language: 'en'),
        ),
        isA<ExchangeCredentialReadFailure>(),
      );
    });
  });

  group('listAnnouncements', () {
    test('maps the announcements', () async {
      final http = FakeBbxHttp(
        body: {
          'result': {
            'elements': [
              {
                'title': 'Maintenance',
                'description': 'Tonight',
                'updatedAt': '2026-11-20T10:00:00Z',
              },
            ],
          },
        },
      );
      final announcements = _valueOf(
        await _repository(http).listAnnouncements(),
      );

      expect(http.requests.single.path, '/ak/api-commcenter');
      expect(announcements.single.title, 'Maintenance');
      expect(announcements.single.description, 'Tonight');
      expect(announcements.single.updatedAt, DateTime.utc(2026, 11, 20, 10));
    });

    test('no stored key is an empty list, not a failure', () async {
      expect(
        _valueOf(await _signedOut(FakeBbxHttp()).listAnnouncements()),
        isEmpty,
      );
    });

    test('an unreadable key is a credential failure', () async {
      expect(
        _failureOf(await _unreadableKey(FakeBbxHttp()).listAnnouncements()),
        isA<ExchangeCredentialReadFailure>(),
      );
    });

    test('a JSON-RPC error is a sanitized failure', () async {
      final failure = _failureOf(
        await _repository(FakeBbxHttp(body: _rpcError)).listAnnouncements(),
      );
      expect(failure, isA<ExchangeAnnouncementsUnavailableFailure>());
      expect(failure.logMessage, isNot(contains('sat@example.com')));
    });
  });
}
