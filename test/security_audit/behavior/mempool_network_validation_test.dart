// Behavioral proof for the audit finding on custom mempool-server validation
// (issue #2622 fix).
//
// `fix(mempool)` compares the genesis block only for Bitcoin mainnet/testnet.
// Both Liquid networks fall into the `_ => null` branch, so a Bitcoin server
// is accepted as a Liquid fee/explorer source.
import 'dart:io';

import 'package:bb_mobile/core/mempool/domain/errors/mempool_failure.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/mempool/interface_adapters/validators/http_mempool_server_validator.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

const _bitcoinMainnetGenesis =
    '000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f';

void main() {
  late HttpServer server;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final path = request.uri.path;
      request.response.statusCode = 200;
      if (path == '/api/v1/blocks/tip/height') {
        request.response.write('880000');
      } else if (path == '/api/block-height/0') {
        // A Bitcoin mainnet server, whatever network the caller asked for.
        request.response.write(_bitcoinMainnetGenesis);
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('rejects a Bitcoin server configured as a Liquid mempool', () async {
    final validator = HttpMempoolServerValidator();

    final result = await validator.validateServer(
      url: '${server.address.address}:${server.port}',
      network: MempoolServerNetwork.liquidMainnet,
      enableSsl: false,
    );

    expect(
      result,
      isA<Err<void, MempoolFailure>>(),
      reason: 'a Bitcoin chain must not validate as a Liquid mempool server',
    );
    expect(
      (result as Err).failure,
      isA<MempoolValidationNetworkMismatchFailure>(),
    );
  });

  test(
    'rejects a Bitcoin mainnet server configured as Liquid testnet',
    () async {
      final validator = HttpMempoolServerValidator();

      final result = await validator.validateServer(
        url: '${server.address.address}:${server.port}',
        network: MempoolServerNetwork.liquidTestnet,
        enableSsl: false,
      );

      expect(result, isA<Err<void, MempoolFailure>>());
    },
  );
}
