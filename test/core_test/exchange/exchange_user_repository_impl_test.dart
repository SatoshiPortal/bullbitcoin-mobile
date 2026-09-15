import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/api_key_model.dart';
import 'package:bb_mobile/core/exchange/data/models/user_preference_payload_model.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_user_repository_impl.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_user_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// The kind of string the exchange stack throws: a transport class name plus an
/// API key and an account email. None of it may survive into a failure.
const _rawReason =
    'DioException [bad response]: apiKey bbk_live_7f3a9c2e '
    'rejected for sat@example.com';

class _MockApiDatasource extends Mock implements BullbitcoinApiDatasource {}

class _MockApiKeyDatasource extends Mock
    implements BullbitcoinApiKeyDatasource {}

class _FakePreferencePayload extends Fake
    implements UserPreferencePayloadModel {}

class _FakeApiKey extends Fake implements ExchangeApiKeyModel {
  @override
  String get key => 'bbk_live_7f3a9c2e';
}

/// Asserts the boundary kept the payload out of the failure.
void _expectSanitized(ExchangeUserFailure failure) {
  final log = failure.logMessage ?? '';
  expect(log, isNot(contains('bbk_live_7f3a9c2e')));
  expect(log, isNot(contains('sat@example.com')));
  expect(log, isNot(contains('DioException')));
  expect(log, isNot(contains('rejected')));
}

void main() {
  setUpAll(() => registerFallbackValue(_FakePreferencePayload()));

  late _MockApiDatasource api;
  late _MockApiKeyDatasource apiKeys;

  ExchangeUserRepositoryImpl build() => ExchangeUserRepositoryImpl(
    bullbitcoinApiDatasource: api,
    bullbitcoinApiKeyDatasource: apiKeys,
    isTestnet: false,
  );

  void givenSignedIn() {
    when(
      () => apiKeys.get(isTestnet: any(named: 'isTestnet')),
    ).thenAnswer((_) async => _FakeApiKey());
  }

  void givenSignedOut() {
    when(
      () => apiKeys.get(isTestnet: any(named: 'isTestnet')),
    ).thenAnswer((_) async => null);
  }

  setUp(() {
    api = _MockApiDatasource();
    apiKeys = _MockApiKeyDatasource();
  });

  group('getUserSummary', () {
    test('a throwing datasource becomes a sanitized failure', () async {
      givenSignedIn();
      when(() => api.getUserSummary(any())).thenThrow(Exception(_rawReason));

      final failure =
          (await build().getUserSummary() as Err).failure
              as ExchangeUserFailure;

      expect(failure, isA<ExchangeUserSummaryUnavailableFailure>());
      _expectSanitized(failure);
    });

    // "No session" and "the call failed" are different user stories: one says
    // log in, the other says retry. The old API collapsed both into `null`.
    test(
      'no stored key is not-authenticated, not a transport failure',
      () async {
        givenSignedOut();

        final failure =
            (await build().getUserSummary() as Err).failure
                as ExchangeUserFailure;

        expect(failure, isA<ExchangeUserNotAuthenticatedFailure>());
        verifyNever(() => api.getUserSummary(any()));
      },
    );

    test('a key that resolves to no account is not-authenticated', () async {
      givenSignedIn();
      when(() => api.getUserSummary(any())).thenAnswer((_) async => null);

      expect(
        (await build().getUserSummary() as Err).failure,
        isA<ExchangeUserNotAuthenticatedFailure>(),
      );
    });
  });

  group('listAnnouncements', () {
    test('a throwing datasource becomes a sanitized failure', () async {
      givenSignedIn();
      when(
        () => api.listAnnouncements(apiKey: any(named: 'apiKey')),
      ).thenThrow(Exception(_rawReason));

      final failure =
          (await build().listAnnouncements() as Err).failure
              as ExchangeUserFailure;

      expect(failure, isA<ExchangeUserAnnouncementsUnavailableFailure>());
      _expectSanitized(failure);
    });

    // Being signed out is not an error here — there is simply nothing to show.
    test('no stored key is an empty list, not a failure', () async {
      givenSignedOut();

      final result = await build().listAnnouncements();

      expect(result, isA<Ok<List<dynamic>, ExchangeUserFailure>>());
      expect((result as Ok).value, isEmpty);
    });
  });

  group('saveUserPreference', () {
    test('a throwing datasource becomes a sanitized failure', () async {
      givenSignedIn();
      when(
        () => api.saveUserPreference(
          apiKey: any(named: 'apiKey'),
          params: any(named: 'params'),
        ),
      ).thenThrow(Exception(_rawReason));

      final failure =
          (await build().saveUserPreference(language: 'en') as Err).failure
              as ExchangeUserFailure;

      expect(failure, isA<ExchangeUserPreferencesSaveFailure>());
      _expectSanitized(failure);
    });

    test('no stored key is not-authenticated', () async {
      givenSignedOut();

      expect(
        (await build().saveUserPreference(language: 'en') as Err).failure,
        isA<ExchangeUserNotAuthenticatedFailure>(),
      );
    });
  });

  group('registerScamWarningConsent', () {
    test('a throwing datasource becomes a sanitized failure', () async {
      givenSignedIn();
      when(
        () => api.registerResponsibilityConsent(any()),
      ).thenThrow(Exception(_rawReason));

      final failure =
          (await build().registerScamWarningConsent() as Err).failure
              as ExchangeUserFailure;

      expect(failure, isA<ExchangeUserConsentRegistrationFailure>());
      _expectSanitized(failure);
    });
  });
}
