import 'dart:convert';
import 'dart:typed_data';

import 'package:bbx_api/bbx_api_testing.dart';
import 'package:dio/dio.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/src/data/pending_orders.dart';
import 'package:exchange/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

final class _Pages implements HttpClientAdapter {
  final List<Object> pages;
  final void Function()? afterPage;
  final requestedPages = <int>[];
  bool closed = false;

  _Pages(this.pages, {this.afterPage});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = options.data as Map;
    final params = data['params'] as Map;
    final paginator = params['paginator'] as Map;
    final page = paginator['page'] as int;
    requestedPages.add(page);
    final body = pages[page - 1];
    afterPage?.call();
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) => closed = true;
}

Map<String, Object> _order(String id, String status) => {
  'orderId': id,
  'orderNumber': 1,
  'orderType': 'Buy Bitcoin',
  'createdAt': '2026-11-20T10:00:00Z',
  'orderStatus': status,
};

Object _page(List<Object> orders) => {
  'result': {'elements': orders},
};

void main() {
  final endpoint = Uri.https('example.invalid');
  var epoch = 0;
  var environment = ExchangeEnvironment.mainnet;
  var authenticated = true;
  setUp(() {
    epoch = 0;
    environment = ExchangeEnvironment.mainnet;
    authenticated = true;
  });

  PendingOrders build(_Pages http) => PendingOrders(
    readSession: () async => Ok((
      endpoint: endpoint,
      environment: environment,
      epoch: epoch,
      apiKey: authenticated ? 'transport-fixture' : null,
    )),
    openClient: (endpoint, readKey) => bbxForTesting(
      endpoint: endpoint.toString(),
      adapter: http,
      readActiveApiKey: readKey,
    ),
  );

  test('only a complete final page establishes absence', () async {
    final http = _Pages([
      _page([_order('one', 'Completed')]),
      _page([]),
    ]);
    final result = await build(http).hasPendingOrders();
    expect(
      result,
      isA<Ok<bool, ExchangeFailure>>().having(
        (result) => result.value,
        'has pending orders',
        isFalse,
      ),
    );
    expect(http.requestedPages, [1, 2]);
    expect(http.closed, isTrue);
  });

  test('checks the full page before interpreting a pending order', () async {
    final http = _Pages([
      _page([_order('one', 'In progress'), _order('two', 'Unknown')]),
    ]);
    expect(
      await build(http).hasPendingOrders(),
      isA<Err<bool, ExchangeFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<ExchangeOrderInventoryUnavailableFailure>(),
      ),
    );
    expect(http.closed, isTrue);
  });

  test('refuses repeated order identifiers across pages', () async {
    final http = _Pages([
      _page([_order('one', 'Completed')]),
      _page([_order('one', 'Completed')]),
    ]);
    expect(
      await build(http).hasPendingOrders(),
      isA<Err<bool, ExchangeFailure>>(),
    );
    expect(http.requestedPages, [1, 2]);
  });

  test('refuses a session that changes while a page is in flight', () async {
    final http = _Pages([_page([])], afterPage: () => epoch++);
    expect(
      await build(http).hasPendingOrders(),
      isA<Err<bool, ExchangeFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<ExchangeOperationStaleFailure>(),
      ),
    );
    expect(http.closed, isTrue);
  });

  test('missing authentication does not send a request', () async {
    authenticated = false;
    final http = _Pages([]);
    expect(
      await build(http).hasPendingOrders(),
      isA<Err<bool, ExchangeFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<ExchangeNotAuthenticatedFailure>(),
      ),
    );
    expect(http.requestedPages, isEmpty);
  });

  test('consumer fake does not need a transport or credentials', () async {
    final exchange = exchangeForTesting(
      hasPendingOrders: () async => const Ok(true),
    );
    expect(
      await exchange.hasPendingOrders(),
      isA<Ok<bool, ExchangeFailure>>().having(
        (result) => result.value,
        'has pending orders',
        isTrue,
      ),
    );
  });
}
