import 'dart:convert';
import 'dart:typed_data';

import 'package:bbx_api/bbx_api.dart';
import 'package:bbx_api/bbx_api_testing.dart';
import 'package:dio/dio.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:primitives/primitives.dart';

class FakeBbxHttp implements HttpClientAdapter {
  final int status;
  final Object? body;
  final DioExceptionType? error;
  final List<RequestOptions> requests = [];
  bool endHistoryAfterFirstPage = false;

  FakeBbxHttp({this.status = 200, this.body, this.error});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (error case final type?) {
      throw DioException(requestOptions: options, type: type);
    }
    final data = options.data;
    final params = data is Map ? data['params'] : null;
    final paginator = params is Map ? params['paginator'] : null;
    final page = paginator is Map ? paginator['page'] : null;
    final response = endHistoryAfterFirstPage && page is int && page > 1
        ? {
            'result': {'elements': <Object>[]},
          }
        : body;
    return ResponseBody.fromString(
      jsonEncode(response),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  Bbx client({Future<Result<String?, BbxFailure>> Function()? readApiKey}) =>
      bbxForTesting(
        endpoint: 'https://example.invalid',
        adapter: this,
        readActiveApiKey: readApiKey ?? () async => const Ok('synthetic-key'),
      );
}

Exchange testExchange(
  HttpClientAdapter adapter, {
  bool isTestnet = false,
  Future<Result<String?, ExchangeFailure>> Function()? readApiKey,
}) => exchangeWithTransportForTesting(
  readSession: () async {
    final credential =
        await (readApiKey?.call() ??
            Future.value(const Ok<String?, ExchangeFailure>('synthetic-key')));
    return credential.map(
      (apiKey) => (
        environment: isTestnet
            ? ExchangeEnvironment.testnet
            : ExchangeEnvironment.mainnet,
        epoch: 0,
        apiKey: apiKey,
      ),
    );
  },
  openClient: (endpoint, readKey) => bbxForTesting(
    endpoint: endpoint.toString(),
    adapter: adapter,
    readActiveApiKey: readKey,
  ),
);

ExchangeOrders testExchangeOrders(
  HttpClientAdapter adapter, {
  bool isTestnet = false,
  Future<Result<String?, ExchangeFailure>> Function()? readApiKey,
}) => testExchange(
  adapter,
  isTestnet: isTestnet,
  readApiKey: readApiKey,
).orders(isTestnet ? ExchangeEnvironment.testnet : ExchangeEnvironment.mainnet);
