import 'dart:async';

import 'package:bull_logger/bull_logger.dart';
import 'package:ledger_bitcoin/ledger_bitcoin.dart';

/// Owns discovery separately from the SDK's shared, fire-and-forget scanner.
/// The datasource owns the deadline; cancellation waits for native stop.
abstract final class LedgerBleScanner {
  static Future<void> _previousScan = Future<void>.value();

  static Stream<LedgerDevice> scan() {
    late final StreamController<LedgerDevice> controller;
    final cancelled = Completer<void>();
    var isCancelled = false;
    Future<void> cleanup = Future<void>.value();

    void forwardError(Object error, StackTrace trace) {
      if (!isCancelled && !controller.isClosed) {
        controller.addError(error, trace);
      }
    }

    Future<void> run(Future<void> previous) async {
      await previous;
      // A queued scan can be cancelled before it owns the native scanner.
      if (isCancelled) return;
      final ids = <String>{};
      final subscription = UniversalBle.scanStream.listen((device) {
        if (isCancelled || !ids.add(device.deviceId)) return;
        controller.add(
          LedgerDevice.ble(
            id: device.deviceId,
            name: device.name ?? '',
            rssi: device.rssi ?? 0,
            // Web advertisements have no services, matching the SDK fallback.
            deviceInfo:
                LedgerDeviceType.fromBleServices(device.services) ??
                LedgerDeviceType.nanoX,
          ),
        );
      }, onError: forwardError);
      try {
        await UniversalBle.startScan(
          scanFilter: ScanFilter(
            withServices: LedgerDeviceType.ble
                .map((type) => type.serviceId)
                .toList(),
          ),
        );
        await cancelled.future;
      } catch (error, trace) {
        forwardError(error, trace);
      } finally {
        try {
          await subscription.cancel();
        } catch (error) {
          log.warning(
            'Error cancelling Ledger BLE advertisements',
            error: error,
          );
        } finally {
          // This session still owns the scanner until the native stop ends.
          try {
            await UniversalBle.stopScan();
          } catch (error) {
            log.warning('Error stopping Ledger BLE discovery', error: error);
          }
        }
      }
    }

    controller = StreamController<LedgerDevice>(
      onListen: () {
        final previous = _previousScan;
        final released = Completer<void>();
        _previousScan = released.future;
        cleanup = run(previous)
            .catchError(forwardError)
            .whenComplete(released.complete);
        // Observe failures immediately, including a synchronous start failure.
        // Never await controller.close from its own cancellation callback.
        unawaited(
          cleanup.then<void>(
            (_) {
              if (!isCancelled) unawaited(controller.close());
            },
            onError: (Object error, StackTrace trace) {
              forwardError(error, trace);
              if (!isCancelled) unawaited(controller.close());
            },
          ),
        );
      },
      onCancel: () {
        isCancelled = true;
        cancelled.complete();
        return cleanup;
      },
    );
    return controller.stream;
  }
}
