import 'dart:convert';
import 'dart:io';

import 'package:fees/fees.dart';
import 'package:mempool/mempool.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Mempool extends Mock implements Mempool {}

class _MempoolServers extends Mock implements MempoolServerSettings {}

class _ElectrumConnections extends Mock implements WalletConnectionPort {}

void main() {
  late HttpServer oracle;
  late ServerSocket socks;
  late int httpHits;
  late int socksConnections;

  setUp(() async {
    httpHits = 0;
    socksConnections = 0;
    oracle = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    oracle.listen((request) {
      httpHits++;
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'fastestFee': 5,
            'halfHourFee': 4,
            'hourFee': 3,
            'economyFee': 2,
            'minimumFee': 1,
          }),
        )
        ..close();
    });
    socks = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    socks.listen((socket) {
      socksConnections++;
      socket.destroy();
    });
  });

  tearDown(() async {
    await oracle.close(force: true);
    await socks.close();
  });

  test('fees reach the direct HTTP oracle and never open SOCKS', () async {
    final electrum = _ElectrumConnections();
    final mempool = _Mempool();
    final mempoolServers = _MempoolServers();
    when(() => mempool.servers).thenReturn(mempoolServers);
    when(() => mempoolServers.activeBase(network: BitcoinNetwork.mainnet))
        .thenAnswer((_) async => Ok(Uri.http('127.0.0.1:${oracle.port}')));

    final fees = Fees.open(connections: electrum, mempool: mempool);
    final result = await fees.estimate(
      BitcoinNetwork.mainnet,
      source: FeeSource.mempool,
    );

    expect(
      result,
      isA<Ok<FeeOptions, FeesFailure>>().having(
        (result) => result.value.fastest.value,
        'fastest',
        5,
      ),
    );
    expect(httpHits, greaterThan(0));
    expect(socksConnections, 0);
    verifyZeroInteractions(electrum);
  });
}
