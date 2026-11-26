import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_bitcoin/ledger_bitcoin.dart';
import 'package:signers/signers.dart';
import 'package:signers/src/ledger/data/datasources/ledger_device_datasource.dart';
import 'package:signers/src/ledger/data/models/ledger_device_model.dart';
import 'package:signers/src/ledger/data/ledger_exception.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ledger_usb');
  late LedgerDeviceDatasource datasource;
  late int opens;
  late int closes;
  late bool available;
  late Future<Object?> Function() open;

  setUp(() {
    datasource = LedgerDeviceDatasource();
    opens = 0;
    closes = 0;
    available = true;
    open = () async => true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'getDevices':
              if (!available) return [];
              return [
                {
                  'identifier': 'ledger-test',
                  'vendorId': 0x2c97,
                  'productId': LedgerDeviceType.nanoSP.productIdMM << 8,
                  'productName': 'Ledger',
                  'deviceId': 1,
                  'deviceName': 'ledger-test',
                },
              ];
            case 'requestPermission':
              return true;
            case 'open':
              opens++;
              return open();
            case 'close':
              closes++;
              return true;
            default:
              throw StateError('Unexpected USB call ${call.method}');
          }
        });
  });
  tearDown(() async {
    await datasource.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<LedgerDeviceModel> scan() async =>
      (await datasource.scanDevices(deviceType: SignerDevice.ledgerNanoSPlus))
          .single;

  test('dispose during USB retry delay prevents another native open', () async {
    final device = await scan();
    final attempted = Completer<void>();
    open = () async {
      if (!attempted.isCompleted) attempted.complete();
      throw PlatformException(code: 'open_failed');
    };
    Object? failure;
    var connected = false;
    final connecting = datasource
        .connectDevice(device)
        .then<void>(
          (_) {
            connected = true;
          },
          onError: (Object error) {
            failure = error;
          },
        );
    await attempted.future;
    await Future<void>.delayed(Duration.zero);
    expect(opens, 1);
    await datasource.dispose();
    await connecting.timeout(const Duration(seconds: 12));
    expect(connected, isFalse);
    expect(failure, isA<DeviceNotFoundLedgerException>());
    expect(opens, 1);
  });

  test('connection completing after dispose is closed and rejected', () async {
    final device = await scan();
    final pending = Completer<Object?>();
    final attempted = Completer<void>();
    open = () {
      attempted.complete();
      return pending.future;
    };
    Object? failure;
    var connected = false;
    final connecting = datasource
        .connectDevice(device)
        .then<void>(
          (_) {
            connected = true;
          },
          onError: (Object error) {
            failure = error;
          },
        );
    await attempted.future;
    await datasource.dispose();
    pending.complete(true);
    await connecting;
    expect(connected, isFalse);
    expect(failure, isA<DeviceNotFoundLedgerException>());
    expect(closes, 1);
  });
  test(
    'a replacement scan invalidates a retry even for the same device ID',
    () async {
      final device = await scan();
      final attempted = Completer<void>();
      open = () async {
        if (!attempted.isCompleted) attempted.complete();
        throw PlatformException(code: 'open_failed');
      };
      final connecting = datasource.connectDevice(device);
      final rejected = expectLater(
        connecting,
        throwsA(isA<DeviceNotFoundLedgerException>()),
      );
      await attempted.future;
      await Future<void>.delayed(Duration.zero);
      final replacement = await scan();
      await rejected;
      expect(opens, 1);
      open = () async => true;
      expect(await datasource.connectDevice(replacement), replacement);
      expect(opens, 2);
    },
  );

  test('timed out open is closed before a replacement may open', () async {
    final device = await scan();
    final pending = Completer<Object?>();
    open = () => pending.future;
    await expectLater(
      datasource.connectDevice(device),
      throwsA(isA<TimeoutException>()),
    );
    await datasource.dispose();
    final replacement = await scan();
    await expectLater(
      datasource.connectDevice(replacement),
      throwsA(isA<NoActiveConnectionLedgerException>()),
    );
    expect(opens, 1);
    pending.complete(true);
    await Future<void>.delayed(Duration.zero);
    expect(closes, 1);
    open = () async {
      expect(
        closes,
        1,
        reason: 'old handle must close before the next native open',
      );
      return true;
    };
    await datasource.connectDevice(replacement);
    await Future<void>.delayed(Duration.zero);
    expect(opens, 2);
    expect(closes, 1, reason: 'late cleanup must not close the new connection');
  });

  test(
    'a failed USB open is retried while its session remains valid',
    () async {
      final device = await scan();
      open = () async {
        if (opens == 1) throw PlatformException(code: 'open_failed');
        return true;
      };
      expect(await datasource.connectDevice(device), device);
      expect(opens, 2);
    },
  );
  test(
    'dispose cancels an unfinished scan before a replacement starts',
    () async {
      available = false;
      final abandoned = datasource.scanDevices(
        deviceType: SignerDevice.ledgerNanoSPlus,
      );
      final rejected = expectLater(
        abandoned,
        throwsA(isA<DeviceNotFoundLedgerException>()),
      );
      await Future<void>.delayed(Duration.zero);
      await datasource.dispose().timeout(const Duration(seconds: 2));
      await rejected;
      available = true;
      final replacement = await scan();
      expect(await datasource.connectDevice(replacement), replacement);
    },
  );
}
