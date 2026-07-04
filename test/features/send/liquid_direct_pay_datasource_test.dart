import 'dart:convert';

import 'package:bb_mobile/features/send/data/datasources/liquid_direct_pay_datasource.dart';
import 'package:bb_mobile/features/send/domain/errors/bullpay_proof_error.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockHttpAdapter extends Mock implements HttpClientAdapter {}

({Dio dio, List<RequestOptions> requests}) _stubDio(
  Object? responseBody, {
  int status = 200,
}) {
  final requests = <RequestOptions>[];
  final adapter = _MockHttpAdapter();
  final dio = Dio(
    BaseOptions(validateStatus: (s) => s != null && s < 600),
  )..httpClientAdapter = adapter;

  when(() => adapter.fetch(any(), any(), any())).thenAnswer((inv) async {
    final opts = inv.positionalArguments[0] as RequestOptions;
    requests.add(opts);
    return ResponseBody.fromString(
      responseBody == null ? '' : jsonEncode(responseBody),
      status,
      headers: {
        'content-type': ['application/json'],
      },
    );
  });

  return (dio: dio, requests: requests);
}

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  group('DioLiquidDirectPayDatasource.fetchMetadata', () {
    test('parses payment_methods and callback, no redirects', () async {
      final stub = _stubDio({
        'tag': 'payRequest',
        'payment_methods': ['L-BTC', 'BOLT11'],
        'callback': 'https://bullpay.test/lnurlp/alice/callback',
      });
      final ds = DioLiquidDirectPayDatasource(dio: stub.dio);

      final meta = await ds.fetchMetadata(
        Uri.https('bullpay.test', '/.well-known/lnurlp/alice'),
      );

      expect(meta.paymentMethods, contains('L-BTC'));
      expect(meta.callback.host, 'bullpay.test');
      expect(stub.requests.single.followRedirects, isFalse);
    });

    test('throws Unavailable when tag is not payRequest', () async {
      final stub = _stubDio({'tag': 'withdrawRequest'});
      final ds = DioLiquidDirectPayDatasource(dio: stub.dio);

      expect(
        () => ds.fetchMetadata(Uri.https('bullpay.test', '/x')),
        throwsA(isA<LiquidDirectPayUnavailable>()),
      );
    });
  });

  group('DioLiquidDirectPayDatasource.requestLiquidPayment', () {
    final callback = Uri.https('bullpay.test', '/lnurlp/alice/callback');
    final query = {
      'amount': '1000000',
      'payment_method': 'L-BTC',
      'outpoint': 'abcd:0',
      'pubkey': 'deadbeef',
      'sig': '3044',
      'value': '1500',
      'value_bf': 'c0ffee',
      'asset': 'a' * 64,
      'asset_bf': 'facade',
    };

    test('issues a GET with the query params and no redirects', () async {
      final stub = _stubDio({
        'L-BTC': {'address': 'lq1qexampleaddress'},
      });
      final ds = DioLiquidDirectPayDatasource(dio: stub.dio);

      await ds.requestLiquidPayment(callback, query: query);

      final req = stub.requests.single;
      expect(req.method, 'GET');
      expect(req.followRedirects, isFalse);
      // The proof + Approach-B payload rides in the query string, not a body.
      expect(req.uri.queryParameters['payment_method'], 'L-BTC');
      expect(req.uri.queryParameters['value_bf'], 'c0ffee');
      expect(req.uri.queryParameters['asset'], 'a' * 64);
      expect(req.uri.queryParameters['asset_bf'], 'facade');
      expect(req.uri.queryParameters['sig'], '3044');
    });

    test('parses the L-BTC address success shape', () async {
      final stub = _stubDio({
        'L-BTC': {'address': 'lq1qexampleaddress'},
      });
      final ds = DioLiquidDirectPayDatasource(dio: stub.dio);

      final result = await ds.requestLiquidPayment(callback, query: query);
      expect(result.liquidAddress, 'lq1qexampleaddress');
      expect(result.bolt11, isNull);
      expect(result.status, isNull);
    });

    test('parses the ERROR envelope with details.min_sat', () async {
      final stub = _stubDio({
        'status': 'ERROR',
        'code': 'ProofOfFundsRequired',
        'reason': 'proof required',
        'details': {'min_sat': 1000},
      });
      final ds = DioLiquidDirectPayDatasource(dio: stub.dio);

      final result = await ds.requestLiquidPayment(callback, query: query);
      expect(result.status, 'ERROR');
      expect(result.code, 'ProofOfFundsRequired');
      expect(result.reason, 'proof required');
      expect(result.minSat, 1000);
    });

    test('parses the Lightning bolt11 soft-fallback shape', () async {
      final stub = _stubDio({'pr': 'lnbc10u1pexample'});
      final ds = DioLiquidDirectPayDatasource(dio: stub.dio);

      final result = await ds.requestLiquidPayment(callback, query: query);
      expect(result.bolt11, 'lnbc10u1pexample');
      expect(result.liquidAddress, isNull);
    });

    test('network failure maps to Unavailable (quiet fallback)', () async {
      final adapter = _MockHttpAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      when(() => adapter.fetch(any(), any(), any())).thenThrow(
        DioException(requestOptions: RequestOptions(path: '/')),
      );
      final ds = DioLiquidDirectPayDatasource(dio: dio);

      expect(
        () => ds.requestLiquidPayment(callback, query: query),
        throwsA(isA<LiquidDirectPayUnavailable>()),
      );
    });
  });
}
