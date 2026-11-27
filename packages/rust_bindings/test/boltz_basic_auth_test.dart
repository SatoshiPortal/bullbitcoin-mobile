import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rust_bindings/boltz.dart';
import 'package:rust_bindings/rust_bindings.dart';

void main() {
  late HttpServer server;
  late List<HttpRequest> requests;

  setUpAll(BullSdk.init);

  setUp(() async {
    requests = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(request);
      request.response.statusCode = HttpStatus.unauthorized;
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  test('credentials in the address are sent as basic authorization and stay '
      'out of the error', () async {
    final fees = Fees(
      boltzUrl: 'http://bull:p%40ss%3Aword@127.0.0.1:${server.port}/v2',
    );

    Object? error;
    try {
      await fees.chain();
    } catch (e) {
      error = e;
    }

    expect(
      requests.single.headers.value(HttpHeaders.authorizationHeader),
      'Basic YnVsbDpwQHNzOndvcmQ=',
    );
    expect(requests.single.uri.path, '/v2/swap/chain');
    expect(error, isNotNull);
    final text = error is BoltzError ? error.message : error.toString();
    expect(text, isNot(contains('p%40ss')));
    expect(text, isNot(contains('p@ss')));
  });
}
