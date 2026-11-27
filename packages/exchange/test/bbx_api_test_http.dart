import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:bbx_api/bbx_api.dart';
import 'package:bbx_api/bbx_api_testing.dart';
import 'package:dio/dio.dart';
import 'package:primitives/primitives.dart';

typedef ReadExchangeApiKey =
    Future<Result<String?, ExchangeFailure>> Function();

Exchange testExchange(
  HttpClientAdapter adapter, {
  bool isTestnet = false,
  ReadExchangeApiKey? readApiKey,
}) => exchangeWithTransportForTesting(
  readSession: () async {
    final credential =
        await (readApiKey?.call() ??
            Future.value(
              const Ok<String?, ExchangeFailure>(anonymousTestApiKey),
            ));
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

OrdersRepository testExchangeOrders(
  HttpClientAdapter adapter, {
  bool isTestnet = false,
  ReadExchangeApiKey? readApiKey,
}) => testExchange(
  adapter,
  isTestnet: isTestnet,
  readApiKey: readApiKey,
).orders(isTestnet ? ExchangeEnvironment.testnet : ExchangeEnvironment.mainnet);

/// The endpoint a test client posts to. Its adapter answers the request, so
/// the host is never resolved.
const testBbxEndpoint = 'https://example.invalid';

/// The credential of a client built without a [ReadExchangeApiKey].
///
/// The old client attached no authentication, so its requests still left the
/// app; returning a key here keeps those requests observable instead of
/// turning them into a missing-credential failure.
const anonymousTestApiKey = 'synthetic-key';

/// The credential the package reads before each request, from the app's
/// [readApiKey].
///
/// A key stays a key and an unreadable credential becomes
/// [BbxCredentialUnavailableFailure]. Without [readApiKey], the read returns
/// [anonymousTestApiKey].
Future<Result<String?, BbxFailure>> Function() bbxCredentialRead(
  ReadExchangeApiKey? readApiKey,
) => readApiKey == null
    ? () async => const Ok<String?, BbxFailure>(anonymousTestApiKey)
    : () async => switch (await readApiKey()) {
        Ok(:final value) => Ok<String?, BbxFailure>(value),
        Err() => const Err<String?, BbxFailure>(
          BbxCredentialUnavailableFailure(),
        ),
      };

/// Answers each request with [status] and [body], or throws [error].
class FakeBbxHttp implements HttpClientAdapter {
  final int status;
  final Object? body;
  final DioExceptionType? error;
  final Object? Function(RequestOptions)? respond;
  final List<RequestOptions> requests = [];

  /// When set, history pages after the first answer an empty page.
  bool endHistoryAfterFirstPage = false;

  FakeBbxHttp({this.status = 200, this.body, this.error, this.respond});

  bool _pastFirstHistoryPage(RequestOptions options) {
    if (!endHistoryAfterFirstPage) return false;
    final data = options.data;
    final params = data is Map ? data['params'] : null;
    final paginator = params is Map ? params['paginator'] : null;
    final page = paginator is Map ? paginator['page'] : null;
    return page is int && page > 1;
  }

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
    final response = switch (respond) {
      final reply? => reply(options),
      null when _pastFirstHistoryPage(options) => {
        'result': {'elements': <Object>[]},
      },
      null => body,
    };
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

  /// A client on this adapter. [readApiKey] is the package's credential read
  /// before each request; without it every request carries
  /// [anonymousTestApiKey].
  Bbx client({Future<Result<String?, BbxFailure>> Function()? readApiKey}) =>
      bbxForTesting(
        endpoint: testBbxEndpoint,
        adapter: this,
        readActiveApiKey: readApiKey ?? bbxCredentialRead(null),
      );
}
