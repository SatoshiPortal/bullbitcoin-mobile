import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_bitcoin/ledger_bitcoin.dart';
import 'package:mocktail/mocktail.dart';
import 'package:signers/signers.dart';
import 'package:signers/src/ledger/data/datasources/ledger_device_datasource.dart';
import 'package:signers/src/ledger/data/datasources/ledger_ble_scanner.dart';
import 'package:signers/src/ledger/data/ledger_exception.dart';

class _BlePlatform extends Mock implements UniversalBlePlatform {
  OnScanResult? callback;
  final advertisements = StreamController<BleDevice>.broadcast();

  @override
  set onScanResultUpdate(OnScanResult? value) => callback = value;

  @override
  Stream<BleDevice> get scanStream => advertisements.stream;

  void advertise(BleDevice device) {
    callback?.call(device);
    advertisements.add(device);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'replacement waits for native BLE stop and survives the old scan deadline',
    () async {
      final platform = _BlePlatform();
      when(() => platform.hasAddressDeviceIds).thenReturn(true);
      when(() => platform.getBluetoothAvailabilityState())
          .thenAnswer((_) async => AvailabilityState.poweredOn);
      UniversalBle.setInstance(platform);
      // Parallel commands are a supported platform mode. The transport must
      // await stop completion independently of the plugin's optional queue.
      UniversalBle.queueType = QueueType.none;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('ledger_usb'),
        (_) async => [],
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (call) async {
          final permissions = call.arguments as List<dynamic>;
          return {for (final permission in permissions) permission: 1};
        },
      );
      final firstStarted = Completer<void>();
      final secondStarted = Completer<void>();
      final firstStop = Completer<void>();
      final releaseStop = Completer<void>();
      var starts = 0;
      var stops = 0;
      when(
        () => platform.startScan(
          scanFilter: any(named: 'scanFilter'),
          platformConfig: any(named: 'platformConfig'),
        ),
      ).thenAnswer((_) async {
        starts++;
        if (starts == 1) firstStarted.complete();
        if (starts == 2) secondStarted.complete();
      });
      when(() => platform.stopScan()).thenAnswer((_) async {
        stops++;
        if (stops == 1) {
          firstStop.complete();
          await releaseStop.future;
        }
      });
      final datasource = LedgerDeviceDatasource();
      try {
        final original = datasource.scanDevices(
          scanDuration: const Duration(milliseconds: 500),
          deviceType: SignerDeviceEntity.ledgerNanoX,
        );
        final originalRejected = expectLater(
          original,
          throwsA(isA<DeviceNotFoundLedgerException>()),
        );
        await firstStarted.future.timeout(const Duration(seconds: 2));
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final disposed = datasource.dispose();
        await firstStop.future.timeout(const Duration(seconds: 2));
        final replacement = datasource.scanDevices(
          scanDuration: const Duration(seconds: 2),
          deviceType: SignerDeviceEntity.ledgerNanoX,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final startsBeforeStopCompleted = starts;
        releaseStop.complete();
        await disposed;
        await originalRejected;
        await secondStarted.future.timeout(const Duration(seconds: 2));
        // A's original 500 ms deadline expires while B must still be listening.
        await Future<void>.delayed(const Duration(milliseconds: 400));
        final stopsBeforeAdvertisement = stops;
        platform.advertise(
          BleDevice(
            deviceId: 'ledger-b',
            name: 'Ledger B',
            services: [LedgerDeviceType.nanoX.serviceId],
          ),
        );
        final devices = await replacement.timeout(const Duration(seconds: 3));
        expect(
          startsBeforeStopCompleted,
          1,
          reason: 'B must wait for the native stop of A',
        );
        expect(
          stopsBeforeAdvertisement,
          1,
          reason: 'A must not stop B at its old deadline',
        );
        expect(devices.map((device) => device.id), ['ledger-b']);
        expect(stops, 2, reason: 'each scan owns exactly one native stop');
      } finally {
        if (!releaseStop.isCompleted) releaseStop.complete();
        await datasource.dispose();
        await platform.advertisements.close();
        messenger.setMockMethodCallHandler(
          const MethodChannel('ledger_usb'),
          null,
        );
        messenger.setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          null,
        );
      }
    },
  );
  test('cancellation during native start drains before queued scans', () async {
    final platform = _BlePlatform();
    when(() => platform.hasAddressDeviceIds).thenReturn(true);
    UniversalBle.setInstance(platform);
    UniversalBle.queueType = QueueType.none;
    final started = Completer<void>();
    final releaseStart = Completer<void>();
    var starts = 0;
    var stops = 0;
    when(
      () => platform.startScan(
        scanFilter: any(named: 'scanFilter'),
        platformConfig: any(named: 'platformConfig'),
      ),
    ).thenAnswer((_) async {
      starts++;
      if (starts == 1) {
        started.complete();
        await releaseStart.future;
      }
    });
    when(() => platform.stopScan()).thenAnswer((_) async {
      stops++;
    });
    final first = LedgerBleScanner.scan().listen((_) {});
    try {
      await started.future.timeout(const Duration(seconds: 2));
      final firstCancelled = first.cancel();
      final queued = LedgerBleScanner.scan().listen((_) {});
      final queuedCancelled = queued.cancel();
      await Future<void>.delayed(Duration.zero);
      expect(starts, 1);
      expect(stops, 0, reason: 'stop must await the pending native start');
      releaseStart.complete();
      await firstCancelled;
      await queuedCancelled;
      expect(starts, 1, reason: 'a cancelled queued scan must never start');
      expect(stops, 1, reason: 'only the owning scan may stop discovery');
      final replacement = LedgerBleScanner.scan().listen((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(starts, 2);
      await replacement.cancel();
      expect(stops, 2);
    } finally {
      if (!releaseStart.isCompleted) releaseStart.complete();
      await first.cancel();
      await platform.advertisements.close();
    }
  });
  test(
    'failed BLE stop preserves discovery and releases the next scan',
    () async {
      final platform = _BlePlatform();
      when(() => platform.hasAddressDeviceIds).thenReturn(true);
      UniversalBle.setInstance(platform);
      UniversalBle.queueType = QueueType.none;
      final started = Completer<void>();
      var starts = 0;
      when(
        () => platform.startScan(
          scanFilter: any(named: 'scanFilter'),
          platformConfig: any(named: 'platformConfig'),
        ),
      ).thenAnswer((_) async {
        starts++;
        if (starts == 1) started.complete();
      });
      when(() => platform.stopScan())
          .thenThrow(StateError('native stop failed'));
      final found = LedgerBleScanner.scan().first;
      await started.future.timeout(const Duration(seconds: 2));
      platform.advertise(
        BleDevice(
          deviceId: 'ledger-a',
          name: 'Ledger A',
          services: [LedgerDeviceType.nanoX.serviceId],
        ),
      );
      expect((await found).id, 'ledger-a');
      final second = LedgerBleScanner.scan().listen((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(starts, 2);
      await second.cancel();
      final startError = StateError('native start failed');
      when(
        () => platform.startScan(
          scanFilter: any(named: 'scanFilter'),
          platformConfig: any(named: 'platformConfig'),
        ),
      ).thenThrow(startError);
      await expectLater(
        LedgerBleScanner.scan().first,
        throwsA(same(startError)),
      );
      await platform.advertisements.close();
    },
  );
}
