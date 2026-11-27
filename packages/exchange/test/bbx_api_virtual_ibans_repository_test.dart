import 'dart:convert';

import 'package:bbx_api/bbx_api.dart' show Bbx, BbxCredentialUnavailableFailure;
import 'package:dio/dio.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'bbx_api_test_http.dart';

const _activeElement = {
  'recipientId': 'viban-1',
  'iban': 'FR7616958000016918327146718',
  'bicCode': 'FIRPFRP2',
  'bankAddress': '1 Rue de la Paix, Paris',
  'ibanCountry': 'FR',
};

Map<String, Object?> _list(List<Map<String, Object?>> elements) => {
  'result': {'elements': elements, 'totalElements': elements.length},
};

Map<String, Object?> _apiError(String code) => {
  'error': {
    'code': -32602,
    'message': 'Invalid params',
    'data': {
      'apiError': {'code': code, 'message': 'refused'},
    },
  },
};

class _Repository {
  final Bbx mainnet;
  final Bbx testnet;

  const _Repository({required this.mainnet, required this.testnet});

  Exchange _exchange(ExchangeEnvironment environment) =>
      exchangeWithTransportForTesting(
        readSession: () async =>
            Ok((environment: environment, epoch: 0, apiKey: 'synthetic-key')),
        openClient: (endpoint, _) =>
            endpoint.host.startsWith('testnet') ? testnet : mainnet,
      );

  Future<Result<VirtualIban?, ExchangeFailure>> find({
    required bool isTestnet,
  }) {
    final environment = isTestnet
        ? ExchangeEnvironment.testnet
        : ExchangeEnvironment.mainnet;
    return _exchange(environment).virtualIbans.find(environment);
  }

  Future<Result<VirtualIban, ExchangeFailure>> create({
    required bool isTestnet,
  }) {
    final environment = isTestnet
        ? ExchangeEnvironment.testnet
        : ExchangeEnvironment.mainnet;
    return _exchange(environment).virtualIbans.create(environment);
  }
}

_Repository _repository(FakeBbxHttp mainnet, [FakeBbxHttp? testnet]) =>
    _Repository(
      mainnet: mainnet.client(),
      testnet: (testnet ?? FakeBbxHttp()).client(),
    );

List<(String, String, Object?)> _sent(FakeBbxHttp http) => [
  for (final r in http.requests)
    (r.path, jsonEncode(r.data), r.headers['x-api-version']),
];

T _valueOf<T>(Result<T, ExchangeFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('expected an Ok, got ${failure.runtimeType}'),
};

ExchangeFailure _failureOf<T>(Result<T, ExchangeFailure> result) =>
    switch (result) {
      Ok() => fail('expected an Err, got Ok'),
      Err(:final failure) => failure,
    };

void main() {
  group('find', () {
    test('asks the selected environment', () async {
      final mainnet = FakeBbxHttp();
      final testnet = FakeBbxHttp(body: _list([]));

      final result = await _repository(mainnet, testnet).find(isTestnet: true);

      expect(_valueOf(result), isNull);
      expect(mainnet.requests, isEmpty);
      expect(_sent(testnet).single, (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":'
            '{"paginator":{"page":1,"pageSize":1},"filters":'
            '{"recipientTypeFiat":["SEPA_EUR_VIRTUAL_ACCOUNT"],'
            '"isOwner":true}}}',
        '2.0.0',
      ));
    });

    test('a missing result means no virtual IBAN', () async {
      final result = await _repository(FakeBbxHttp(body: {'result': null}))
          .find(isTestnet: false);

      expect(_valueOf(result), isNull);
    });

    test('returns an active virtual IBAN', () async {
      final iban = _valueOf(
        await _repository(FakeBbxHttp(body: _list([_activeElement])))
            .find(isTestnet: false),
      );

      expect(
        iban,
        isA<ActiveVirtualIban>()
            .having((i) => i.iban, 'iban', 'FR7616958000016918327146718')
            .having((i) => i.bicCode, 'bicCode', 'FIRPFRP2')
            .having(
              (i) => i.bankAddress,
              'bankAddress',
              '1 Rue de la Paix, Paris',
            )
            .having((i) => i.ibanCountry, 'ibanCountry', 'FR'),
      );
    });

    test('returns a pending virtual IBAN', () async {
      final iban = _valueOf(
        await _repository(
          FakeBbxHttp(
            body: _list([
              {'recipientId': 'viban-1'},
            ]),
          ),
        ).find(isTestnet: false),
      );

      expect(iban, isA<PendingVirtualIban>());
    });

    test('a refused funding option means no virtual IBAN yet', () async {
      final result = await _repository(
        FakeBbxHttp(body: _apiError('ERR_RCP_PO404')),
      ).find(isTestnet: false);

      expect(_valueOf(result), isNull);
    });

    test('another refusal is unexpected', () async {
      final failure = _failureOf(
        await _repository(FakeBbxHttp(body: _apiError('ERR_RCP_500')))
            .find(isTestnet: false),
      );

      expect(failure, isA<ExchangeUnexpectedFailure>());
      expect(
        failure.logMessage,
        'BbxRpcFailure(code: -32602, apiCode: ERR_RCP_500)',
      );
    });

    test('a malformed element is unexpected', () async {
      final result = await _repository(
        FakeBbxHttp(
          body: _list([
            {'iban': 42},
          ]),
        ),
      ).find(isTestnet: false);

      expect(_failureOf(result), isA<ExchangeUnexpectedFailure>());
    });

    test('a status other than 200 is unexpected', () async {
      final result = await _repository(FakeBbxHttp(status: 204))
          .find(isTestnet: false);

      expect(_failureOf(result), isA<ExchangeUnexpectedFailure>());
    });

    test('no credential is not authenticated', () async {
      final http = FakeBbxHttp();
      final repository = _Repository(
        mainnet: http.client(readApiKey: () async => const Ok(null)),
        testnet: FakeBbxHttp().client(),
      );

      expect(
        _failureOf(await repository.find(isTestnet: false)),
        isA<ExchangeNotAuthenticatedFailure>(),
      );
      expect(http.requests, isEmpty);
    });

    test('an unreadable credential is not an absent account', () async {
      final repository = _Repository(
        mainnet: FakeBbxHttp().client(
          readApiKey: () async => const Err(BbxCredentialUnavailableFailure()),
        ),
        testnet: FakeBbxHttp().client(),
      );

      final failure = _failureOf(await repository.find(isTestnet: false));

      expect(failure, isA<ExchangeCredentialReadFailure>());
      expect(failure.logMessage, isNull);
    });
  });

  group('create', () {
    test('creates the virtual IBAN', () async {
      final body = {
        'result': {'element': _activeElement},
      };
      final http = FakeBbxHttp(body: body);

      final result = await _repository(http).create(isTestnet: false);

      expect(_valueOf(result), isA<ActiveVirtualIban>());
      expect(_sent(http).single, (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"createMyRecipient","params":'
            '{"element":{"recipientType":"FR_VIRTUAL_ACCOUNT",'
            '"isOwner":true}}}',
        null,
      ));
    });

    final refusals = {
      'ERR_RCP_PO404': isA<ExchangeVirtualIbanNotAvailableFailure>(),
      'ERR_RCP_400_001': isA<ExchangeEuResidencyRequiredFailure>(),
      'ERR_RCP_400': isA<ExchangeUnexpectedFailure>(),
    };
    for (final MapEntry(key: code, value: failure) in refusals.entries) {
      test('$code is mapped like before', () async {
        final result = await _repository(FakeBbxHttp(body: _apiError(code)))
            .create(isTestnet: false);

        expect(_failureOf(result), failure);
      });
    }

    test('an unreachable API is a network failure', () async {
      final result = await _repository(
        FakeBbxHttp(error: DioExceptionType.connectionTimeout),
      ).create(isTestnet: false);

      expect(_failureOf(result), isA<ExchangeNetworkFailure>());
    });

    test('a result without an element is unexpected', () async {
      final result = await _repository(
        FakeBbxHttp(body: {'result': <String, Object?>{}}),
      ).create(isTestnet: false);

      expect(_failureOf(result), isA<ExchangeUnexpectedFailure>());
    });
  });
}
