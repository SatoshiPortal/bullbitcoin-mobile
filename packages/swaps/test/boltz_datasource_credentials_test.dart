import 'dart:io';

import 'package:boltz_stream/boltz_stream.dart';
import 'package:flutter_test/flutter_test.dart' show TestWidgetsFlutterBinding;
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show NetworkEnv;
import 'package:swaps/src/data/boltz_api.dart';
import 'package:swaps/src/data/swap_storage.dart';
import 'package:swaps/swaps.dart' show SwapServerCredentials;
import 'package:test/test.dart';

import 'support/real_swap_backends.dart';

class _MockRowStore extends Mock implements SwapRowStore {}

class _MockWebSocket extends Mock implements BoltzWebSocket {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const credentials = SwapServerCredentials(
    username: 'bull',
    password: 'p@ss:word',
  );

  late HttpServer server;
  late List<HttpRequest> requests;
  late List<({String url, Map<String, String>? headers})> sockets;

  setUp(() async {
    requests = [];
    sockets = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(request);
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  BoltzDatasource datasource({SwapServerCredentials? credentials}) {
    final boltz = BoltzDatasource(
      environment: NetworkEnv.testnet,
      url: 'http://127.0.0.1:${server.port}/v2',
      credentials: credentials,
      boltzStore: SwapStorage(
        rows: _MockRowStore(),
        secrets: ReproKeychainBackend().capability,
      ),
      webSocketFactory: (url, {headers, onDone, onError}) {
        sockets.add((url: url, headers: headers));
        final socket = _MockWebSocket();
        when(() => socket.stream).thenAnswer((_) => const Stream.empty());
        return socket;
      },
    );
    addTearDown(boltz.dispose);
    return boltz;
  }

  test('status requests carry the basic authorization', () async {
    await HttpOverrides.runZoned(
      () => datasource(credentials: credentials).reconcileSwaps(['swap-1']),
      createHttpClient: (context) =>
          _RealHttpOverrides().createHttpClient(context),
    );

    expect(requests.single.uri.path, '/v2/swap/swap-1');
    expect(
      requests.single.headers.value(HttpHeaders.authorizationHeader),
      credentials.authorization,
    );
  });

  test('status requests carry no authorization without credentials', () async {
    await HttpOverrides.runZoned(
      () => datasource().reconcileSwaps(['swap-1']),
      createHttpClient: (context) =>
          _RealHttpOverrides().createHttpClient(context),
    );

    expect(
      requests.single.headers.value(HttpHeaders.authorizationHeader),
      isNull,
    );
  });

  test('the websocket gets the authorization as a header, not in its '
      'address', () {
    datasource(credentials: credentials).subscribeToSwaps(['swap-1']);

    expect(sockets.single.url, 'ws://127.0.0.1:${server.port}/v2');
    expect(sockets.single.headers, {
      'authorization': credentials.authorization,
    });
  });

  test('the websocket gets no header without credentials', () {
    datasource().subscribeToSwaps(['swap-1']);

    expect(sockets.single.headers, isNull);
  });
}

class _RealHttpOverrides extends HttpOverrides {}
