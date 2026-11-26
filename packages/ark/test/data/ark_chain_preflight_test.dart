import 'dart:io';

import 'package:ark/ark.dart';
import 'package:ark/src/data/ark_chain_preflight.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  final servers = <HttpServer>[];
  tearDown(() async {
    for (final server in servers) {
      await server.close(force: true);
    }
    servers.clear();
  });
  Future<({Uri uri, List<String> calls})> server({
    int status = 200,
    String? genesis,
    int tip = 100,
  }) async {
    final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    servers.add(http);
    final calls = <String>[];
    http.listen((request) async {
      calls.add(request.uri.path);
      request.response.statusCode = status;
      request.response.write(
        request.uri.path.endsWith('/block-height/0')
            ? genesis ?? '0f9188f13cb7b2c71f2a335e3a4fc328bf5beb436012afca590b1a11466e2206'
            : tip.toString(),
      );
      await request.response.close();
    });
    return (uri: Uri.parse('http://127.0.0.1:${http.port}'), calls: calls);
  }

  ArkAccountConfig config(Uri primary, Uri fallback) => ArkAccountConfig(
    id: ArkAccountId(
      parent: Fingerprint('12345678'),
      network: BitcoinNetwork.regtest,
      serverIdentity: 'test',
    ),
    arkUrl: Uri.parse('http://localhost:3535'),
    primaryEsploraUrl: primary,
    fallbackEsploraUrl: fallback,
  );
  const preflight = HttpArkChainPreflight();
  test('unreachable primary alone permits validated fallback', () async {
    final unused = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final unavailable = Uri.parse('http://127.0.0.1:${unused.port}');
    await unused.close();
    final fallback = await server();
    final result = await preflight.select(
      config(unavailable, fallback.uri),
      minimumTip: 100,
    );
    expect((result as Ok<Uri, ArkWalletFailure>).value, fallback.uri);
    expect(fallback.calls, ['/blocks/tip/height', '/block-height/0']);
  });
  test('HTTP error is reachable and never switches provider', () async {
    final primary = await server(status: 503);
    final fallback = await server();
    expect(
      await preflight.select(config(primary.uri, fallback.uri)),
      isA<Err>(),
    );
    expect(fallback.calls, isEmpty);
  });
  test('wrong genesis never switches provider', () async {
    final primary = await server(genesis: 'wrong');
    final fallback = await server();
    expect(
      await preflight.select(config(primary.uri, fallback.uri)),
      isA<Err>(),
    );
    expect(fallback.calls, isEmpty);
  });
  test(
    'tip regression is rejected before native admission without fallback',
    () async {
      final primary = await server(tip: 99);
      final fallback = await server();
      expect(
        await preflight.select(
          config(primary.uri, fallback.uri),
          minimumTip: 100,
        ),
        isA<Err>(),
      );
      expect(fallback.calls, isEmpty);
    },
  );
  test(
    'pinned unreachable source never falls back even before spend',
    () async {
      final unused = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final unavailable = Uri.parse('http://127.0.0.1:${unused.port}');
      await unused.close();
      final fallback = await server();
      expect(
        await preflight.select(
          config(unavailable, fallback.uri),
          requiredSource: unavailable,
        ),
        isA<Err>(),
      );
      expect(fallback.calls, isEmpty);
    },
  );
}
