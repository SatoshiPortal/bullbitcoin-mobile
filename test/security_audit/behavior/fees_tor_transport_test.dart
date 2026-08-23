import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:bb_mobile/core/mempool/domain/entities/mempool_settings.dart';
import 'package:bb_mobile/core/mempool/domain/entities/mempool_server.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_server_repository.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_settings_repository.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/fees/fees_locator.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class _MempoolSettings extends Mock implements MempoolSettingsRepository {}

class _MempoolServers extends Mock implements MempoolServerRepository {}

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

  setUpAll(() {
    registerFallbackValue(
      MempoolServerNetwork.fromEnvironment(isTestnet: false, isLiquid: false),
    );
  });

  setUp(() async {
    httpHits = 0;
    socksConnections = 0;
    oracle = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    oracle.listen((request) {
      httpHits++;
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'fastestFee': 5,
          'halfHourFee': 4,
          'hourFee': 3,
          'economyFee': 2,
          'minimumFee': 1,
        }))
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
    final mempoolSettings = _MempoolSettings();
    final mempoolServers = _MempoolServers();
    final network = MempoolServerNetwork.fromEnvironment(
      isTestnet: false,
      isLiquid: false,
    );
    final server = MempoolServer.existing(
      url: '127.0.0.1:${oracle.port}',
      network: network,
      isCustom: true,
      enableSsl: false,
    );

    when(() => globalSettings.fetch()).thenAnswer(
      (_) async => _torSettings(socks.port),
    );
    when(() => mempoolSettings.fetchByNetwork(network)).thenAnswer(
      (_) async => Ok(
        MempoolSettings.existing(
          network: network,
          useForFeeEstimation: true,
        ),
      ),
    );
    when(() => mempoolServers.fetchCustomServer(network)).thenAnswer(
      (_) async => Ok(server),
    );

    locator.registerSingleton<SettingsRepository>(globalSettings);
    locator.registerSingleton<MempoolSettingsRepository>(mempoolSettings);
    locator.registerSingleton<MempoolServerRepository>(mempoolServers);
    FeesLocator.registerDatasources(locator);
    FeesLocator.registerRepositories(locator);

    final result = await locator<FeesRepository>().getNetworkFees(
      network: Network.bitcoinMainnet,
    );

    expect(result.fastest.value, 5);
    expect(httpHits, greaterThan(0));
    expect(socksConnections, 0);
  });
}
