import 'dart:convert';

import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/features/recipients/data/bbx_api_virtual_iban_repository.dart';
import 'package:bb_mobile/features/recipients/data/datasources/bullbitcoin_api_virtual_iban_datasource.dart';
import 'package:bb_mobile/features/recipients/data/virtual_iban_repository_impl.dart';
import 'package:bb_mobile/features/recipients/domain/entities/virtual_iban.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../exchange/data/bbx_api_test_http.dart';

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

BbxApiVirtualIbanRepository _repository(
  FakeBbxHttp mainnet, [
  FakeBbxHttp? testnet,
]) => BbxApiVirtualIbanRepository(
  mainnet: mainnet.client(),
  testnet: (testnet ?? FakeBbxHttp()).client(),
);

VirtualIbanRepositoryImpl _old(FakeBbxHttp mainnet) =>
    VirtualIbanRepositoryImpl(
      mainnetDatasource: BullbitcoinApiVirtualIbanDatasource(
        http: Dio(BaseOptions(baseUrl: 'https://example.invalid'))
          ..httpClientAdapter = mainnet,
      ),
      testnetDatasource: BullbitcoinApiVirtualIbanDatasource(http: Dio()),
    );

List<(String, String, Object?)> _sent(FakeBbxHttp http) => [
  for (final r in http.requests)
    (r.path, jsonEncode(r.data), r.headers['x-api-version']),
];

T _valueOf<T>(Result<T, RecipientsFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('expected an Ok, got ${failure.runtimeType}'),
};

RecipientsFailure _failureOf<T>(Result<T, RecipientsFailure> result) =>
    switch (result) {
      Ok() => fail('expected an Err, got Ok'),
      Err(:final failure) => failure,
    };

void main() {
  group('find', () {
    test('asks the selected environment, like the old datasource', () async {
      final mainnet = FakeBbxHttp();
      final testnet = FakeBbxHttp(body: _list([]));
      final old = FakeBbxHttp(body: _list([]));

      final result = await _repository(mainnet, testnet).find(isTestnet: true);
      await _old(old).find(isTestnet: false);

      expect(_valueOf(result), isNull);
      expect(mainnet.requests, isEmpty);
      expect(_sent(testnet), _sent(old));
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

      expect(failure, isA<RecipientsUnexpectedFailure>());
      expect(
        failure.logMessage,
        'BbxApiRpcException(code: -32602, apiCode: ERR_RCP_500)',
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

      expect(_failureOf(result), isA<RecipientsUnexpectedFailure>());
    });

    test('a status other than 200 is unexpected', () async {
      final result = await _repository(FakeBbxHttp(status: 204))
          .find(isTestnet: false);

      expect(_failureOf(result), isA<RecipientsUnexpectedFailure>());
    });

    test('no credential is not authenticated', () async {
      final http = FakeBbxHttp();
      final repository = BbxApiVirtualIbanRepository(
        mainnet: http.client(readApiKey: () async => const Ok(null)),
        testnet: FakeBbxHttp().client(),
      );

      expect(
        _failureOf(await repository.find(isTestnet: false)),
        isA<RecipientsNotAuthenticatedFailure>(),
      );
      expect(http.requests, isEmpty);
    });

    test('an unreadable credential is unexpected', () async {
      final repository = BbxApiVirtualIbanRepository(
        mainnet: FakeBbxHttp().client(
          readApiKey: () async => const Err(ExchangeApiKeyReadFailure()),
        ),
        testnet: FakeBbxHttp().client(),
      );

      final failure = _failureOf(await repository.find(isTestnet: false));

      expect(failure, isA<RecipientsUnexpectedFailure>());
      expect(failure.logMessage, 'Exchange credential unavailable');
    });
  });

  group('create', () {
    test('creates the virtual IBAN, like the old datasource', () async {
      final body = {
        'result': {'element': _activeElement},
      };
      final http = FakeBbxHttp(body: body);
      final old = FakeBbxHttp(body: body);

      final result = await _repository(http).create(isTestnet: false);
      await _old(old).create(isTestnet: false);

      expect(_valueOf(result), isA<ActiveVirtualIban>());
      expect(_sent(http), _sent(old));
      expect(_sent(http).single, (
        '/ak/api-recipients',
        '{"jsonrpc":"2.0","id":"0","method":"createMyRecipient","params":'
            '{"element":{"recipientType":"FR_VIRTUAL_ACCOUNT",'
            '"isOwner":true}}}',
        null,
      ));
    });

    final refusals = {
      'ERR_RCP_PO404': isA<RecipientsVirtualIbanNotAvailableFailure>(),
      'ERR_RCP_400_001': isA<RecipientsEuResidencyRequiredFailure>(),
      'ERR_RCP_400': isA<RecipientsUnexpectedFailure>(),
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

      expect(_failureOf(result), isA<RecipientsNetworkFailure>());
    });

    test('a result without an element is unexpected', () async {
      final result = await _repository(
        FakeBbxHttp(body: {'result': <String, Object?>{}}),
      ).create(isTestnet: false);

      expect(_failureOf(result), isA<RecipientsUnexpectedFailure>());
    });
  });
}
