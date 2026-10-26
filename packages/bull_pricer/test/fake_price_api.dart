import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// One request the price API received.
final class FakePriceRequest {
  /// The host the request was addressed to, e.g. `api.bullbitcoin.com`.
  final String host;

  /// The JSON-RPC method, e.g. `getRate`.
  final String method;

  /// The JSON-RPC `params.element`.
  final Map<String, Object?> params;

  /// The `X-API-Key` header, or null when none was sent.
  final String? apiKey;

  const FakePriceRequest({
    required this.host,
    required this.method,
    required this.params,
    required this.apiKey,
  });
}

/// An HTTP answer: a status and a JSON body.
typedef FakePriceAnswer = ({int status, Object body});

FakePriceAnswer element(Map<String, Object> element) => (
  status: 200,
  body: {
    'jsonrpc': '2.0',
    'id': 1,
    'result': {'element': element},
  },
);

/// Mainnet and testnet answer different index prices, so a test can tell
/// which network served a price.
const mainnetIndexPrice = 11421420;
const testnetIndexPrice = 5000000;

/// Answers like the real API: `getRate` with the index price of the network
/// the request was addressed to.
FakePriceAnswer realisticAnswer(FakePriceRequest request) {
  final indexPrice = request.host.contains('api05')
      ? testnetIndexPrice
      : mainnetIndexPrice;
  return element({'indexPrice': indexPrice, 'precision': 2});
}

/// Stands in for the Bull Bitcoin price API.
///
/// The pricer builds its own HTTP clients with the real URLs, so the API is
/// replaced underneath them: while installed, every connection Dart opens is
/// sent to a local server, which answers with [respond] and records each
/// request.
final class FakePriceApi {
  final HttpServer _server;
  final requests = <FakePriceRequest>[];
  FakePriceAnswer Function(FakePriceRequest request) respond = realisticAnswer;

  /// When set, every answer waits for it.
  Future<void>? answerAfter;

  /// When true, every connection is dropped without an answer, as when the
  /// device is offline.
  bool offline = false;

  FakePriceApi._(this._server) {
    _server.listen(_answer);
  }

  static Future<FakePriceApi> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final api = FakePriceApi._(server);
    HttpOverrides.global = _LocalOverrides(server.port);
    return api;
  }

  int callsTo(String method) =>
      requests.where((r) => r.method == method).length;

  Future<void> close() async {
    HttpOverrides.global = null;
    await _server.close(force: true);
  }

  Future<void> _answer(HttpRequest httpRequest) async {
    final rpc =
        jsonDecode(await utf8.decoder.bind(httpRequest).join())
            as Map<String, Object?>;
    final request = FakePriceRequest(
      host: httpRequest.headers.host ?? '',
      method: rpc['method'] as String,
      params: ((rpc['params'] as Map)['element'] as Map).cast(),
      apiKey: httpRequest.headers.value('X-API-Key'),
    );
    requests.add(request);
    await answerAfter;
    if (offline) {
      final socket = await httpRequest.response.detachSocket(
        writeHeaders: false,
      );
      socket.destroy();
      return;
    }

    final answer = respond(request);
    httpRequest.response
      ..statusCode = answer.status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(answer.body));
    await httpRequest.response.close();
  }
}

/// Sends every connection to the local server, over plain HTTP, whatever host
/// and scheme the request names.
final class _LocalOverrides extends HttpOverrides {
  final int _port;

  _LocalOverrides(this._port);

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..connectionFactory = (uri, proxyHost, proxyPort) =>
            Socket.startConnect(InternetAddress.loopbackIPv4, _port);
}
