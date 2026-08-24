import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/ledger_failure.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/connect_ledger_device_usecase.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/disconnect_ledger_device_usecase.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/dispose_ledger_connections_usecase.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/scan_ledger_devices_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/ledger/presentation/cubit/ledger_operation_cubit.dart';
import 'package:bb_mobile/features/ledger/presentation/cubit/ledger_operation_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockScanLedgerDevicesUsecase extends Mock
    implements ScanLedgerDevicesUsecase {}

class _MockConnectLedgerDeviceUsecase extends Mock
    implements ConnectLedgerDeviceUsecase {}

class _MockDisconnectLedgerDeviceUsecase extends Mock
    implements DisconnectLedgerDeviceUsecase {}

class _MockDisposeLedgerConnectionsUsecase extends Mock
    implements DisposeLedgerConnectionsUsecase {}

void main() {
  late _MockScanLedgerDevicesUsecase scan;
  late _MockConnectLedgerDeviceUsecase connect;
  late _MockDisconnectLedgerDeviceUsecase disconnect;
  late _MockDisposeLedgerConnectionsUsecase disposeConnections;

  const device = LedgerDeviceEntity(
    id: 'device-1',
    name: 'Nano X',
    connectionType: LedgerConnectionType.usb,
    deviceType: SignerDeviceEntity.ledgerNanoX,
  );

  setUpAll(() {
    registerFallbackValue(device);
  });

  setUp(() {
    scan = _MockScanLedgerDevicesUsecase();
    connect = _MockConnectLedgerDeviceUsecase();
    disconnect = _MockDisconnectLedgerDeviceUsecase();
    disposeConnections = _MockDisposeLedgerConnectionsUsecase();

    when(() => disposeConnections.execute()).thenAnswer((_) async {});
    when(() => disconnect.execute(any())).thenAnswer((_) async {});
  });

  LedgerOperationCubit buildCubit() => LedgerOperationCubit(
    scanLedgerDevicesUsecase: scan,
    connectLedgerDeviceUsecase: connect,
    disconnectLedgerDeviceUsecase: disconnect,
    disposeLedgerConnectionsUsecase: disposeConnections,
  );

  void stubScan(Result<List<LedgerDeviceEntity>, LedgerFailure> result) {
    when(
      () => scan.execute(deviceType: any(named: 'deviceType')),
    ).thenAnswer((_) async => result);
  }

  void stubConnect(Result<void, LedgerFailure> result) {
    when(() => connect.execute(any())).thenAnswer((_) async => result);
  }

  Future<List<LedgerOperationStatus>> capture(
    LedgerOperationCubit cubit,
    Future<void> Function() run,
  ) async {
    final statuses = <LedgerOperationStatus>[];
    final sub = cubit.stream.listen((s) => statuses.add(s.status));
    await run();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    return statuses;
  }

  group('LedgerOperationCubit.executeOperation', () {
    test('walks scanning → connecting → processing → success', () async {
      final cubit = buildCubit();
      stubScan(Ok([device]));
      stubConnect(const Ok(null));

      final statuses = await capture(
        cubit,
        () => cubit.executeOperation(
          () async => const Ok<dynamic, LedgerFailure>('signed'),
        ),
      );

      expect(statuses, [
        LedgerOperationStatus.scanning,
        LedgerOperationStatus.connecting,
        LedgerOperationStatus.processing,
        LedgerOperationStatus.success,
      ]);
      expect(cubit.state.result, 'signed');
      expect(cubit.state.failure, isNull);
      expect(cubit.state.connectedDevice, device);
      await cubit.close();
    });

    test('emits scan failure and stops before connecting', () async {
      final cubit = buildCubit();
      stubScan(const Err(LedgerPermissionDeniedFailure()));

      final statuses = await capture(
        cubit,
        () => cubit.executeOperation(
          () async => const Ok<dynamic, LedgerFailure>('unused'),
        ),
      );

      expect(statuses, [
        LedgerOperationStatus.scanning,
        LedgerOperationStatus.error,
      ]);
      expect(cubit.state.failure, isA<LedgerPermissionDeniedFailure>());
      verifyNever(() => connect.execute(any()));
      await cubit.close();
    });

    test('emits LedgerNoDevicesFoundFailure when scan returns Ok(empty) '
        '— nothing thrown across the boundary', () async {
      final cubit = buildCubit();
      stubScan(Ok(const <LedgerDeviceEntity>[]));

      final statuses = await capture(
        cubit,
        () => cubit.executeOperation(
          () async => const Ok<dynamic, LedgerFailure>('unused'),
        ),
      );

      expect(statuses, [
        LedgerOperationStatus.scanning,
        LedgerOperationStatus.error,
      ]);
      expect(cubit.state.failure, isA<LedgerNoDevicesFoundFailure>());
      verifyNever(() => connect.execute(any()));
      await cubit.close();
    });

    test('emits connect failure and never runs the operation', () async {
      final cubit = buildCubit();
      stubScan(Ok([device]));
      stubConnect(const Err(LedgerDeviceLockedFailure()));
      var operationRan = false;

      final statuses = await capture(cubit, () async {
        await cubit.executeOperation(() async {
          operationRan = true;
          return const Ok<dynamic, LedgerFailure>('unused');
        });
      });

      expect(statuses, [
        LedgerOperationStatus.scanning,
        LedgerOperationStatus.connecting,
        LedgerOperationStatus.error,
      ]);
      expect(cubit.state.failure, isA<LedgerDeviceLockedFailure>());
      expect(operationRan, isFalse);
      await cubit.close();
    });

    test('emits the operation failure at the processing step', () async {
      final cubit = buildCubit();
      stubScan(Ok([device]));
      stubConnect(const Ok(null));

      final statuses = await capture(
        cubit,
        () => cubit.executeOperation(
          () async =>
              const Err<dynamic, LedgerFailure>(LedgerRejectedByUserFailure()),
        ),
      );

      expect(statuses, [
        LedgerOperationStatus.scanning,
        LedgerOperationStatus.connecting,
        LedgerOperationStatus.processing,
        LedgerOperationStatus.error,
      ]);
      expect(cubit.state.failure, isA<LedgerRejectedByUserFailure>());
      await cubit.close();
    });
  });
}
