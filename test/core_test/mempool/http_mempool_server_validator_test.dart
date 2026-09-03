import 'dart:io';

import 'package:bb_mobile/core/mempool/domain/errors/mempool_failure.dart';
import 'package:bb_mobile/core/mempool/domain/ports/mempool_tor_session_port.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/mempool/interface_adapters/validators/http_mempool_server_validator.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/self_signed_certificate_fixture.dart';

final class _UnusedTorSessionPort implements MempoolTorSessionPort {
  @override
  Future<MempoolTorRoute?> open({required String serverUrl}) {
    throw StateError('Clearnet validation must not open a Tor session');
  }
}

void _serveMempoolApi(HttpServer server) {
  server.listen((request) async {
    request.response.headers.contentType = ContentType.text;
    switch (request.uri.path) {
      case '/api/v1/blocks/tip/height':
        request.response.write('1');
      case '/api/block-height/0':
        request.response.write(
          '000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f',
        );
      default:
        request.response.statusCode = HttpStatus.notFound;
    }
    await request.response.close();
  });
}

void main() {
  late SelfSignedCertificateFixture fixture;

  setUpAll(() async => fixture = await SelfSignedCertificateFixture.create());
  tearDownAll(() => fixture.dispose());

  Future<({HttpMempoolServerValidator validator, String url})>
  startServer() async {
    final server = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      fixture.securityContext,
    );
    addTearDown(() => server.close(force: true));
    _serveMempoolApi(server);
    return (
      validator: HttpMempoolServerValidator(
        torSessionPort: _UnusedTorSessionPort(),
        torHttpClientFactory: const TorHttpClientFactory(),
      ),
      url: '127.0.0.1:${server.port}',
    );
  }

  test('rejects a self-signed certificate by default', () async {
    final (:validator, :url) = await startServer();

    final result = await validator.validateServer(
      url: url,
      network: MempoolServerNetwork.bitcoinMainnet,
    );

    expect(result, isA<Err<void, MempoolFailure>>());
  });

  test('accepts a self-signed certificate when explicitly allowed', () async {
    final (:validator, :url) = await startServer();

    final result = await validator.validateServer(
      url: url,
      network: MempoolServerNetwork.bitcoinMainnet,
      validateDomain: false,
    );

    expect(result, isA<Ok<void, MempoolFailure>>());
  });
}
