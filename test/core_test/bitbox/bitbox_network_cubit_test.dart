import 'package:bb_mobile/core/bitbox/domain/errors/bitbox_failure.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/connect_bitbox_device_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/scan_bitbox_devices_usecase.dart';
import 'package:bb_mobile/features/bitbox/domain/disconnect_bitbox_device_usecase.dart';
import 'package:bb_mobile/features/bitbox/domain/dispose_bitbox_connections_usecase.dart';
import 'package:bb_mobile/features/bitbox/presentation/cubit/bitbox_operation_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Scan extends Mock implements ScanBitBoxDevicesUsecase {}

class _Connect extends Mock implements ConnectBitBoxDeviceUsecase {}

class _Disconnect extends Mock implements DisconnectBitBoxDeviceUsecase {}

class _Dispose extends Mock implements DisposeBitBoxConnectionsUsecase {}

void main() {
  for (final network in [NetworkEnv.regtest, NetworkEnv.signet]) {
    test(
      '$network refuses discovery and pairing before any device IO',
      () async {
        final scan = _Scan();
        final connect = _Connect();
        final disconnect = _Disconnect();
        final dispose = _Dispose();
        when(() => dispose.execute()).thenAnswer((_) async => const Ok(null));
        final cubit = BitBoxOperationCubit(
          network: network,
          scanBitBoxDevicesUsecase: scan,
          connectBitBoxDeviceUsecase: connect,
          disconnect: disconnect,
          dispose: dispose,
        );
        var operationCalled = false;
        await cubit.executeOperation(() async {
          operationCalled = true;
          return const Ok(null);
        });
        expect(operationCalled, isFalse);
        expect(cubit.state.failure, isA<InvalidParametersBitBoxFailure>());
        verifyZeroInteractions(scan);
        verifyZeroInteractions(connect);
        verifyZeroInteractions(disconnect);
        await cubit.close();
        verify(() => dispose.execute()).called(1);
      },
    );
  }
}
