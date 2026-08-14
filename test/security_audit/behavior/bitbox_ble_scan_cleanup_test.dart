// Behavioral proof for the BitBox BLE scan lifecycle (issue #2652 follow-up).
//
// The settle-window rewrite opened the scan subscription BEFORE the guarded
// block, so a failing `startScan` (permission denied, radio switched off
// between the availability check and the scan) left the subscription — and its
// callback — alive for the rest of the process.
import 'dart:async';

import 'package:bb_mobile/core/bitbox/data/datasources/bitbox_device_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:universal_ble/universal_ble.dart';

class _FakeBlePlatform extends Mock implements UniversalBlePlatform {}

void main() {
  late _FakeBlePlatform platform;
  late StreamController<BleDevice> scanController;
  late int listenCount;
  late int cancelCount;

  setUp(() {
    listenCount = 0;
    cancelCount = 0;
    scanController = StreamController<BleDevice>(
      onListen: () => listenCount++,
      onCancel: () => cancelCount++,
    );

    platform = _FakeBlePlatform();
    when(
      () => platform.getBluetoothAvailabilityState(),
    ).thenAnswer((_) async => AvailabilityState.poweredOn);
    when(() => platform.scanStream).thenAnswer((_) => scanController.stream);
    when(() => platform.stopScan()).thenAnswer((_) async {});
    UniversalBle.setInstance(platform);
  });

  tearDown(() async {
    if (!scanController.isClosed) await scanController.close();
  });

  test('a failing startScan leaves no live scan subscription', () async {
    when(
      () => platform.startScan(
        scanFilter: any(named: 'scanFilter'),
        platformConfig: any(named: 'platformConfig'),
      ),
    ).thenThrow(Exception('bluetooth turned off mid-scan'));

    await expectLater(
      BitBoxDeviceDatasource().scanDevices(),
      throwsA(anything),
    );

    expect(
      listenCount,
      1,
      reason: 'the scan subscription is opened before startScan runs',
    );
    expect(
      cancelCount,
      1,
      reason: 'a failed startScan must not leak the subscription',
    );
  });
}
