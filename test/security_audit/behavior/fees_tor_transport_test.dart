import 'package:electrum/setup.dart';

import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:mempool/mempool.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:primitives/primitives.dart'
    show BitcoinNetwork, BitcoinUnit, Ok;
import 'package:bb_mobile/features/fees/fees_locator.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class _Mempool extends Mock implements Mempool {}

class _MempoolServers extends Mock implements MempoolServerSettings {}

class _ElectrumServers extends Mock implements ElectrumServersPort {}

class _GlobalSettings extends Mock implements SettingsRepository {}

SettingsEntity _torSettings(int port) => SettingsEntity(
  environment: Environment.mainnet,
  bitcoinUnit: BitcoinUnit.sats,
  currencyCode: 'USD',
  useTorProxy: true,
  torProxyPort: port,
);

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
    final locator = GetIt.asNewInstance();
    final globalSettings = _GlobalSettings();
    final electrumServers = _ElectrumServers();
    final mempool = _Mempool();
    final mempoolServers = _MempoolServers();
    when(() => globalSettings.fetch())
        .thenAnswer((_) async => _torSettings(socks.port));
    when(() => mempool.servers).thenReturn(mempoolServers);
    when(() => mempoolServers.activeBase(network: BitcoinNetwork.mainnet))
        .thenAnswer((_) async => Ok(Uri.http('127.0.0.1:${oracle.port}')));

    locator.registerSingleton<SettingsRepository>(globalSettings);
    locator.registerSingleton<Mempool>(mempool);
    locator.registerSingleton<ElectrumServersPort>(electrumServers);
    FeesLocator.registerDatasources(locator);
    FeesLocator.registerRepositories(locator);

    final result = await locator<FeesRepository>().getNetworkFees(
      network: Network.bitcoinMainnet,
    );

    expect(result.fastest.value, 5);
    expect(httpHits, greaterThan(0));
    expect(socksConnections, 0);
    verifyZeroInteractions(electrumServers);
  });
}
