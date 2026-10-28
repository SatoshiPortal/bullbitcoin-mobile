import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/api_key_model.dart';
import 'package:bb_mobile/core/exchange/data/repository/bbx_api_exchange_user_repository.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_user_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../core/exchange/fake_bbx_api.dart';

class _MockApiKeyDatasource extends Mock
    implements BullbitcoinApiKeyDatasource {}

class _FakeApiKey extends Fake implements ExchangeApiKeyModel {
  @override
  String get key => 'key';
}

Map<String, dynamic> _summary() => {
  'userNumber': 42,
  'userId': 'user-1',
  'groups': <String>[],
  'profile': {'firstName': 'Test', 'lastName': 'User'},
  'email': 'test.user@example.com',
  'balances': <Object>[],
  'emailNotificationsEnabled': true,
  'twoFaEnabled': false,
  'dca': {'isActive': false},
  'autoBuy': {'isActive': false, 'addresses': <String, Object>{}},
  'kycDocumentStatus': {
    'secureFileUpload': 'NOT_UPLOADED',
    'documents': {
      'id': 'NOT_UPLOADED',
      'proofOfResidence': 'NOT_UPLOADED',
      'selfie': 'NOT_UPLOADED',
    },
  },
};

const _refusal = {
  'jsonrpc': '2.0',
  'id': '1',
  'error': {'code': -32603, 'message': 'secret detail'},
};

void main() {
  late FakeBbxApi api;
  late _MockApiKeyDatasource apiKeys;
  late BbxApiExchangeUserRepository repository;

  setUp(() {
    api = FakeBbxApi();
    apiKeys = _MockApiKeyDatasource();
    when(
      () => apiKeys.get(isTestnet: false),
    ).thenAnswer((_) async => _FakeApiKey());
    repository = BbxApiExchangeUserRepository(
      api: api.datasource(),
      apiKeyDatasource: apiKeys,
      isTestnet: false,
    );
  });

  group('getUserSummary', () {
    test('reads the summary', () async {
      api.answers.add(rpcResult(_summary()));

      final summary =
          (await repository.getUserSummary()
                  as Ok<UserSummary, ExchangeUserFailure>)
              .value;

      expect(summary.userId, 'user-1');
      expect(api.payloads.single['method'], 'getUserSummary');
    });

    test('no stored key is not authenticated and sends nothing', () async {
      when(() => apiKeys.get(isTestnet: false)).thenAnswer((_) async => null);

      final result = await repository.getUserSummary();

      expect(
        (result as Err<UserSummary, ExchangeUserFailure>).failure,
        isA<ExchangeUserNotAuthenticatedFailure>(),
      );
      expect(api.payloads, isEmpty);
    });

    test('a key the gateway refuses is not authenticated', () async {
      api.answers.add(
        const FakeHttpStatus(401, {
          'error': {'code': 401, 'status': 'Unauthorized'},
        }),
      );

      expect(
        (await repository.getUserSummary()
                as Err<UserSummary, ExchangeUserFailure>)
            .failure,
        isA<ExchangeUserNotAuthenticatedFailure>(),
      );
    });

    test('an unreachable API is a network failure', () async {
      api.answers.add(dio.DioExceptionType.connectionError);

      expect(
        (await repository.getUserSummary()
                as Err<UserSummary, ExchangeUserFailure>)
            .failure,
        isA<ExchangeUserNetworkFailure>(),
      );
    });

    test('a refusal is a summary failure without the server text', () async {
      api.answers.add(_refusal);

      final failure =
          (await repository.getUserSummary()
                  as Err<UserSummary, ExchangeUserFailure>)
              .failure;

      expect(failure, isA<ExchangeUserSummaryUnavailableFailure>());
      expect(failure.logMessage, isNot(contains('secret detail')));
    });
  });

  group('saveUserPreference', () {
    test('sends each preference under its server key', () async {
      api.answers.add(rpcResult({'success': true}));

      final result = await repository.saveUserPreference(
        language: 'en',
        currency: 'CAD',
        dcaEnabled: true,
        autoBuyEnabled: false,
        emailNotificationsEnabled: true,
      );

      expect(result, isA<Ok<void, ExchangeUserFailure>>());
      expect(api.payloads.single['method'], 'saveUserPreferences');
      expect(api.payloads.single['params'], {
        'userPreferences': {
          'LANGUAGE': 'en',
          'DEFAULT_FIAT_CURRENCY_CODE': 'CAD',
          'DCA_ENABLED': 'true',
          'AUTO_BUY_ENABLED': 'false',
          'EMAIL_NOTIFICATIONS': 'true',
        },
      });
    });

    test('leaves out the preferences that are not set', () async {
      api.answers.add(rpcResult({'success': true}));

      await repository.saveUserPreference(language: 'fr', currency: 'EUR');

      expect(api.payloads.single['params'], {
        'userPreferences': {
          'LANGUAGE': 'fr',
          'DEFAULT_FIAT_CURRENCY_CODE': 'EUR',
        },
      });
    });
  });
}
