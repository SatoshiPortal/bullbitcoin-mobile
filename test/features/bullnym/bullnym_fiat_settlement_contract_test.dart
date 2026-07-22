import 'dart:convert';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/data/bullnym_http_client.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_fiat_settlement_actions.dart';
import 'package:bb_mobile/features/bullnym/domain/bullpay_signing.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockHttpAdapter extends Mock implements HttpClientAdapter {}

class _Captured {
  final List<RequestOptions> requests = [];
}

({Dio dio, _Captured captured}) _stubDio(
  List<({Object? body, int status})> responses,
) {
  final captured = _Captured();
  final adapter = _MockHttpAdapter();
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://bullpay.test',
      validateStatus: (status) => status != null && status < 600,
    ),
  )..httpClientAdapter = adapter;
  var index = 0;

  when(() => adapter.fetch(any(), any(), any())).thenAnswer((invocation) async {
    final options = invocation.positionalArguments[0] as RequestOptions;
    captured.requests.add(options);
    final response = responses[index++];
    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.status,
      headers: {
        'content-type': ['application/json'],
      },
    );
  });

  return (dio: dio, captured: captured);
}

List<int> _oracleMessageBytes({
  required String action,
  required String npubHex,
  required List<String> payloadFields,
  required int timestampSecs,
}) {
  final bytes = <int>[];
  for (final value in [
    bullpayWireDomain,
    action,
    npubHex,
    '',
    ...payloadFields,
  ]) {
    bytes
      ..addAll(utf8.encode(value))
      ..add(0);
  }
  bytes.addAll(utf8.encode(timestampSecs.toString()));
  return bytes;
}

void main() {
  const timestamp = 1710000000;
  const npubHex =
      '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';
  const scopedKey =
      'bbak-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  late List<String> signedHashes;
  late BullnymAuthSigner signer;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  setUp(() {
    signedHashes = [];
    signer = BullnymAuthSigner(
      npubHex: npubHex,
      signHashHex: (hashHex) {
        signedHashes.add(hashHex);
        return '11' * 64;
      },
    );
  });

  test('pins the set and get signed action layouts byte-exactly', () {
    expect(bullpayActionFiatSettlementSet, 'fiat-settlement-set');
    expect(bullpayActionFiatSettlementGet, 'fiat-settlement-get');

    // Enable: 5 payload fields → 9 NUL separators (domain, action, npub, nym,
    // + 5 fields).
    expect(
      buildFiatSettlementSetPayloadFields(
        product: 'payment_page',
        fiatPercentage: 50,
        currencyOrEmpty: 'CAD',
        apiKeyOrEmpty: scopedKey,
      ),
      ['1', 'payment_page', '50', 'CAD', scopedKey],
    );
    final enableMessage = _unwrap(
      buildBullpaySchnorrMessage(
        action: bullpayActionFiatSettlementSet,
        npubHex: npubHex,
        nymOrEmpty: '',
        payloadFields: const ['1', 'payment_page', '50', 'CAD', scopedKey],
        timestampSecs: timestamp,
      ),
    );
    expect(enableMessage.where((byte) => byte == 0), hasLength(9));

    // Disable: empty currency and api_key slots — still 5 fields, still 9 NULs.
    expect(
      buildFiatSettlementSetPayloadFields(
        product: 'pos',
        fiatPercentage: 0,
        currencyOrEmpty: '',
        apiKeyOrEmpty: '',
      ),
      ['1', 'pos', '0', '', ''],
    );
    final disableMessage = _unwrap(
      buildBullpaySchnorrMessage(
        action: bullpayActionFiatSettlementSet,
        npubHex: npubHex,
        nymOrEmpty: '',
        payloadFields: const ['1', 'pos', '0', '', ''],
        timestampSecs: timestamp,
      ),
    );
    expect(disableMessage.where((byte) => byte == 0), hasLength(9));

    expect(buildFiatSettlementGetPayloadFields(), const ['1']);
  });

  group('set', () {
    test('enable sends currency + key and pins the signed hash', () async {
      final stub = _stubDio([
        (
          body: {
            'version': 1,
            'settings': [
              {
                'product': 'payment_page',
                'fiat_percentage': 50,
                'fiat_currency': 'CAD',
              },
            ],
            'credential_status': 'active',
          },
          status: 200,
        ),
      ]);
      final facade = BullnymFacade(
        client: BullnymHttpClient.withDio(stub.dio, nowSecs: () => timestamp),
      );

      final config = _unwrap(
        await facade.setFiatSettlement(
          signer: signer,
          product: BullnymFiatSettlementProduct.paymentPage,
          fiatPercentage: 50,
          fiatCurrency: 'CAD',
          apiKey: scopedKey,
        ),
      );

      expect(config.credentialStatus, BullnymCredentialStatus.active);
      final setting = config.settingFor(
        BullnymFiatSettlementProduct.paymentPage,
      )!;
      expect(setting.fiatPercentage, 50);
      expect(setting.fiatCurrency, 'CAD');

      final request = stub.captured.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/api/v1/fiat-settlement/payment_page');
      expect(request.data, {
        'version': 1,
        'npub': npubHex,
        'fiat_percentage': 50,
        'fiat_currency': 'CAD',
        'api_key': scopedKey,
        'timestamp': timestamp,
        'signature': '11' * 64,
      });
      expect(signedHashes, [
        sha256
            .convert(
              _oracleMessageBytes(
                action: 'fiat-settlement-set',
                npubHex: npubHex,
                payloadFields: const [
                  '1',
                  'payment_page',
                  '50',
                  'CAD',
                  scopedKey,
                ],
                timestampSecs: timestamp,
              ),
            )
            .toString(),
      ]);
    });

    test('disable (0%) omits currency and api_key from the body', () async {
      final stub = _stubDio([
        (
          body: {
            'version': 1,
            'settings': <dynamic>[],
            'credential_status': 'active',
          },
          status: 200,
        ),
      ]);
      final facade = BullnymFacade(
        client: BullnymHttpClient.withDio(stub.dio, nowSecs: () => timestamp),
      );

      final config = _unwrap(
        await facade.setFiatSettlement(
          signer: signer,
          product: BullnymFiatSettlementProduct.pos,
          fiatPercentage: 0,
        ),
      );
      expect(config.settings, isEmpty);

      final data = stub.captured.requests.single.data as Map<String, dynamic>;
      expect(data.keys, isNot(contains('fiat_currency')));
      expect(data.keys, isNot(contains('api_key')));
      expect(data['fiat_percentage'], 0);
    });

    test(
      'rejects a 0% request that carries a currency before any I/O',
      () async {
        final stub = _stubDio(const []);
        final client = BullnymHttpClient.withDio(
          stub.dio,
          nowSecs: () => timestamp,
        );

        final result = await client.setFiatSettlement(
          signer: signer,
          product: BullnymFiatSettlementProduct.pos,
          fiatPercentage: 0,
          fiatCurrency: 'CAD',
        );
        final failure =
            (result as Err<BullnymFiatSettlementConfiguration, BullnymFailure>)
                .failure;
        expect(failure.kind, BullnymFailureKind.invalidInput);
        expect(signedHashes, isEmpty);
        expect(stub.captured.requests, isEmpty);
      },
    );

    test(
      'rejects a nonzero request without a currency before any I/O',
      () async {
        final stub = _stubDio(const []);
        final client = BullnymHttpClient.withDio(
          stub.dio,
          nowSecs: () => timestamp,
        );

        final result = await client.setFiatSettlement(
          signer: signer,
          product: BullnymFiatSettlementProduct.pos,
          fiatPercentage: 50,
        );
        expect(
          ((result as Err).failure as BullnymFailure).kind,
          BullnymFailureKind.invalidInput,
        );
        expect(signedHashes, isEmpty);
        expect(stub.captured.requests, isEmpty);
      },
    );

    for (final code in const [
      'FIAT_CONVERSION_KYC_REQUIRED',
      'FIAT_CREDENTIAL_REQUIRED',
      'FIAT_CREDENTIAL_INVALID',
    ]) {
      test('passes through the stable server code $code', () async {
        final stub = _stubDio([
          (
            body: {'status': 'ERROR', 'code': code, 'reason': 'nope'},
            status: 200,
          ),
        ]);
        final client = BullnymHttpClient.withDio(
          stub.dio,
          nowSecs: () => timestamp,
        );

        final result = await client.setFiatSettlement(
          signer: signer,
          product: BullnymFiatSettlementProduct.invoice,
          fiatPercentage: 100,
          fiatCurrency: 'USD',
          apiKey: scopedKey,
        );
        final failure = (result as Err).failure as BullnymFailure;
        expect(failure.kind, BullnymFailureKind.serverRejectedRequest);
        expect(failure.code, code);
      });
    }

    test('surfaces a 503 dependency outage as a retryable failure', () async {
      final stub = _stubDio([
        (
          body: {
            'status': 'ERROR',
            'code': 'ServiceUnavailable',
            'reason': 'down',
          },
          status: 503,
        ),
      ]);
      final client = BullnymHttpClient.withDio(
        stub.dio,
        nowSecs: () => timestamp,
      );

      final result = await client.setFiatSettlement(
        signer: signer,
        product: BullnymFiatSettlementProduct.invoice,
        fiatPercentage: 100,
        fiatCurrency: 'USD',
        apiKey: scopedKey,
      );
      final failure = (result as Err).failure as BullnymFailure;
      expect(failure.retryable, isTrue);
      expect(failure.statusCode, 503);
    });
  });

  group('getConfiguration', () {
    test('parses settings and skips unknown products', () async {
      final stub = _stubDio([
        (
          body: {
            'version': 1,
            'settings': [
              {
                'product': 'lightning_address',
                'fiat_percentage': 25,
                'fiat_currency': 'EUR',
              },
              {
                'product': 'future_product',
                'fiat_percentage': 100,
                'fiat_currency': 'USD',
              },
            ],
            'credential_status': 'active',
          },
          status: 200,
        ),
      ]);
      final facade = BullnymFacade(
        client: BullnymHttpClient.withDio(stub.dio, nowSecs: () => timestamp),
      );

      final config = _unwrap(
        await facade.getFiatSettlementConfiguration(signer: signer),
      );
      expect(config.settings, hasLength(1));
      expect(
        config
            .settingFor(BullnymFiatSettlementProduct.lightningAddress)!
            .fiatPercentage,
        25,
      );
      final request = stub.captured.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/api/v1/fiat-settlement');
    });

    test('degrades a 404 (old server) to an empty configuration', () async {
      final stub = _stubDio([(body: <String, dynamic>{}, status: 404)]);
      final facade = BullnymFacade(
        client: BullnymHttpClient.withDio(stub.dio, nowSecs: () => timestamp),
      );

      final config = _unwrap(
        await facade.getFiatSettlementConfiguration(signer: signer),
      );
      expect(config.settings, isEmpty);
      expect(config.credentialStatus, BullnymCredentialStatus.unknown);
      final request = stub.captured.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/api/v1/fiat-settlement');
    });

    test('maps an unknown credential status to unknown', () async {
      final stub = _stubDio([
        (
          body: {
            'version': 1,
            'settings': <dynamic>[],
            'credential_status': 'brand_new_status',
          },
          status: 200,
        ),
      ]);
      final facade = BullnymFacade(
        client: BullnymHttpClient.withDio(stub.dio, nowSecs: () => timestamp),
      );

      final config = _unwrap(
        await facade.getFiatSettlementConfiguration(signer: signer),
      );
      expect(config.credentialStatus, BullnymCredentialStatus.unknown);
      expect(config.credentialStatus.isActive, isFalse);
    });
  });
}

T _unwrap<T>(Result<T, BullnymFailure> result) {
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => fail('Expected Ok, got ${failure.code}'),
  };
}
