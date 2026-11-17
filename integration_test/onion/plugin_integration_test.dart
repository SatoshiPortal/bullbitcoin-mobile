import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:onion/onion.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // The bridge refuses a second initialization in the same process.
  setUpAll(OnionCore.init);

  testWidgets('starts and stops the local SOCKS listener', (tester) async {
    final root = await Directory.systemTemp.createTemp('onion_test_');
    final service = await TorService.start(
      stateDir: '${root.path}/state',
      cacheDir: '${root.path}/cache',
      socksPort: 0,
      policy: SocksPolicy.any,
    );

    expect(await service.socksPort(), greaterThan(0));
    expect(await service.proxyIsAlive(), isTrue);

    final firstSession = await service.openSession(
      socksPort: 0,
      policy: SocksPolicy.any,
    );
    final secondSession = await service.openSession(
      socksPort: 0,
      policy: SocksPolicy.any,
    );
    expect(await firstSession.socksPort(), greaterThan(0));
    expect(
      await firstSession.socksPort(),
      isNot(await secondSession.socksPort()),
    );

    await firstSession.stop();
    expect(await firstSession.proxyIsAlive(), isFalse);
    expect(await secondSession.proxyIsAlive(), isTrue);

    await service.stop();
    expect(await service.proxyIsAlive(), isFalse);
    expect(await secondSession.proxyIsAlive(), isFalse);
  });

  testWidgets('watches bootstrap status without a runtime panic', (
    tester,
  ) async {
    final root = await Directory.systemTemp.createTemp('onion_status_');
    final service = await TorService.start(
      stateDir: '${root.path}/state',
      cacheDir: '${root.path}/cache',
      socksPort: 0,
      policy: SocksPolicy.any,
    );
    final errors = <Object>[];
    final subscription = service.watchStatus().listen(
      (_) {},
      onError: errors.add,
    );

    await Future<void>.delayed(const Duration(milliseconds: 250));

    expect(errors, isEmpty);
    await subscription.cancel();
    await service.stop();
    await root.delete(recursive: true);
  });

  testWidgets('routes an Arti client through the native Snowflake listener', (
    tester,
  ) async {
    final root = await Directory.systemTemp.createTemp('onion_snowflake_');
    TorService? service;
    try {
      final snowflakePort = await SnowflakeTransport.start();
      expect(snowflakePort, inInclusiveRange(1, 65535));
      expect(await SnowflakeTransport.version(), contains('2.14.1'));

      service = await TorService.startWithSnowflake(
        stateDir: '${root.path}/state',
        cacheDir: '${root.path}/cache',
        socksPort: 0,
        snowflakePort: snowflakePort,
        policy: SocksPolicy.any,
      );
      final status = await service.status();
      expect(status.transport, TorTransport.snowflake);
      expect(status.readyForTraffic, isFalse);
    } finally {
      await service?.stop();
      await SnowflakeTransport.stop();
      await root.delete(recursive: true);
    }
  }, skip: !Platform.isAndroid && !Platform.isIOS);

  testWidgets('starts Snowflake again after a stop in the same process', (
    tester,
  ) async {
    await SnowflakeTransport.start();
    await SnowflakeTransport.stop();

    try {
      expect(await SnowflakeTransport.start(), inInclusiveRange(1, 65535));
    } finally {
      await SnowflakeTransport.stop();
    }
  }, skip: !Platform.isAndroid && !Platform.isIOS);
}
