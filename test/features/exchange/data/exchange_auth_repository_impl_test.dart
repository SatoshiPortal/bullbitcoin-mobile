import 'dart:convert';
import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/entity/exchange_api_key.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/exchange/data/exchange_auth_repository_impl.dart';
import 'package:bb_mobile/features/exchange/data/exchange_web_auth_datasource.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/complete_exchange_authentication_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

const fields = {
  'id': 'id',
  'key': 'synthetic-key',
  'name': 'name',
  'userId': 'user',
  'isActive': true,
  'createdAt': 0,
  'updatedAt': 0,
};

ExchangeAuthRepositoryImpl _repository(Future<Object> Function() response) =>
    ExchangeAuthRepositoryImpl(
      datasource: ExchangeWebAuthDatasource(
        isTestnet: true,
        evaluateJavaScript: (_) => response(),
        isOpen: () => true,
      ),
    );

class _Keys extends Fake implements ExchangeApiKeyRepository {
  ExchangeApiKey? saved;
  var writes = 0;
  bool? savedEnvironment;
  Result<void, ExchangeApiKeyFailure> result = const Ok(null);
  @override
  Future<Result<void, ExchangeApiKeyFailure>> saveApiKey(
    ExchangeApiKey key, {
    required bool isTestnet,
  }) async {
    writes++;
    saved = key;
    savedEnvironment = isTestnet;
    return result;
  }
}

void main() {
  for (final payload in <String, Object>{
    'bare': fields,
    'apiKey': {'apiKey': fields},
    'result': {
      'result': {'apiKey': fields},
    },
    'data': {
      'data': {'apiKey': fields},
    },
    'json': jsonEncode({'apiKey': fields}),
    'webview-quoted-json': jsonEncode(jsonEncode({'apiKey': fields})),
  }.entries) {
    test('decodes ${payload.key} at the repository boundary', () async {
      final result = await _repository(
        () async => payload.value,
      ).generateApiKey();
      switch (result) {
        case Ok(:final value):
          expect(value.key, 'synthetic-key');
          expect(value.createdAt, 0);
          expect(value.toString(), isNot(contains(value.key)));
        case Err():
          fail('Expected a validated credential');
      }
    });
  }

  test(
    'ISO metadata keeps the existing timestamp storage representation',
    () async {
      final record = {
        ...fields,
        'createdAt': '2026-10-20T12:00:00Z',
        'updatedAt': '2026-10-20T13:00:00Z',
        'lastUsedAt': '2026-10-20T14:00:00Z',
        'expiresAt': '2000-01-01T00:00:00Z',
      };
      final response = jsonEncode(jsonEncode({'apiKey': record}));
      final result = await _repository(() async => response).generateApiKey();
      switch (result) {
        case Ok(:final value):
          expect(
            value.createdAt,
            DateTime.utc(2026, 10, 20, 12).millisecondsSinceEpoch,
          );
          expect(
            value.lastUsedAt,
            DateTime.utc(2026, 10, 20, 14).millisecondsSinceEpoch,
          );
          expect(value.expiresAt, DateTime.utc(2000).millisecondsSinceEpoch);
        case Err():
          fail('An active credential must not gain a new expiry policy');
      }
    },
  );

  for (final payload in <Object>[
    'broken synthetic-key',
    'null',
    [],
    {'error': 'synthetic-key'},
    {...fields, 'key': ''},
    {...fields, 'key': 'synthetic\r\nheader'},
    {...fields, 'isActive': false},
    {...fields, 'isActive': 'true'},
    {...fields, 'createdAt': 'broken'},
    {...fields, 'expiresAt': []},
  ]) {
    test(
      'invalid auth input is a sanitized failure: ${payload.runtimeType}',
      () async {
        final result = await _repository(() async => payload).generateApiKey();
        expect(
          result,
          isA<Err<ExchangeApiKey, ExchangeFailure>>().having(
            (r) => r.failure,
            'failure',
            isA<ExchangeAuthenticationFailure>(),
          ),
        );
        if (result case Err(:final failure)) {
          expect(failure.logMessage, isNot(contains('synthetic-key')));
        }
      },
    );
  }

  test(
    'platform exceptions become failures; programmer errors propagate',
    () async {
      expect(
        await _repository(
          () async => throw Exception('synthetic-key'),
        ).generateApiKey(),
        isA<Err<ExchangeApiKey, ExchangeFailure>>(),
      );
      await expectLater(
        _repository(() async => throw StateError('bug')).generateApiKey(),
        throwsStateError,
      );
    },
  );

  test('the operation persists in its original session environment', () async {
    final keys = _Keys();
    for (final environment in [true, false]) {
      final usecase = CompleteExchangeAuthenticationUsecase(
        authRepository: _repository(() async => fields),
        apiKeyRepository: keys,
        isTestnet: environment,
      );
      expect(await usecase.execute(), isA<Ok<void, ExchangeFailure>>());
      expect(keys.savedEnvironment, environment);
      expect(keys.saved?.key, 'synthetic-key');
    }
  });

  test('a storage failure stays distinct from failed authentication', () async {
    final keys = _Keys()..result = const Err(ExchangeApiKeySaveFailure());
    final result = await CompleteExchangeAuthenticationUsecase(
      authRepository: _repository(() async => fields),
      apiKeyRepository: keys,
      isTestnet: true,
    ).execute();
    expect(
      result,
      isA<Err<void, ExchangeFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeApiKeyStorageFailure>(),
      ),
    );
  });

  for (final closeBefore in [true, false]) {
    test(
      'closing ${closeBefore ? 'before' : 'during'} generation prevents persistence',
      () async {
        var open = !closeBefore;
        var calls = 0;
        final keys = _Keys();
        final datasource = ExchangeWebAuthDatasource(
          isTestnet: true,
          evaluateJavaScript: (_) async {
            calls++;
            open = false;
            return fields;
          },
          isOpen: () => open,
        );
        final result = await CompleteExchangeAuthenticationUsecase(
          authRepository: ExchangeAuthRepositoryImpl(datasource: datasource),
          apiKeyRepository: keys,
          isTestnet: true,
        ).execute();
        expect(result, isA<Err<void, ExchangeFailure>>());
        expect(keys.saved, isNull);
        expect(calls, closeBefore ? 0 : 1);
      },
    );
  }

  test(
    'concurrent completion requests generate and store one credential',
    () async {
      final response = Completer<Object>();
      var calls = 0;
      final keys = _Keys();
      final usecase = CompleteExchangeAuthenticationUsecase(
        authRepository: _repository(() {
          calls++;
          return response.future;
        }),
        apiKeyRepository: keys,
        isTestnet: true,
      );
      final first = usecase.execute();
      final second = usecase.execute();
      response.complete(fields);
      expect(await first, isA<Ok<void, ExchangeFailure>>());
      expect(await second, isA<Ok<void, ExchangeFailure>>());
      expect(calls, 1);
      expect(keys.writes, 1);
    },
  );

  test('a failed authentication attempt can be explicitly retried', () async {
    var calls = 0;
    final keys = _Keys();
    final usecase = CompleteExchangeAuthenticationUsecase(
      authRepository: _repository(
        () async => ++calls == 1 ? {'error': 'refused'} : fields,
      ),
      apiKeyRepository: keys,
      isTestnet: true,
    );
    expect(await usecase.execute(), isA<Err<void, ExchangeFailure>>());
    expect(await usecase.execute(), isA<Ok<void, ExchangeFailure>>());
    expect(calls, 2);
    expect(keys.writes, 1);
  });

  test('the adapter uses the captured auth endpoint', () async {
    for (final environment in [true, false]) {
      String? script;
      final datasource = ExchangeWebAuthDatasource(
        isTestnet: environment,
        evaluateJavaScript: (js) async {
          script = js;
          return '{}';
        },
        isOpen: () => true,
      );
      await datasource.generateApiKeyResponse();
      final base = environment
          ? ApiServiceConstants.bbAuthTestUrl
          : ApiServiceConstants.bbAuthUrl;
      expect(script, contains(jsonEncode('$base/api/generate-api-key')));
      expect(script, contains('xhr.withCredentials = true'));
    }
  });
}
