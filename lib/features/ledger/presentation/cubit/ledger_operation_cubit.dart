import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/ledger_failure.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/connect_ledger_device_usecase.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/disconnect_ledger_device_usecase.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/dispose_ledger_connections_usecase.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/scan_ledger_devices_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/ledger/presentation/cubit/ledger_operation_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LedgerOperationCubit extends Cubit<LedgerOperationState> {
  final ScanLedgerDevicesUsecase _scanLedgerDevicesUsecase;
  final ConnectLedgerDeviceUsecase _connectLedgerDeviceUsecase;
  final DisconnectLedgerDeviceUsecase _disconnectLedgerDeviceUsecase;
  final DisposeLedgerConnectionsUsecase _disposeLedgerConnectionsUsecase;
  final SignerDeviceEntity? _requestedDeviceType;

  LedgerOperationCubit({
    required this._scanLedgerDevicesUsecase,
    required this._connectLedgerDeviceUsecase,
    required this._disconnectLedgerDeviceUsecase,
    required this._disposeLedgerConnectionsUsecase,
    this._requestedDeviceType,
  }) : super(const LedgerOperationState());

  LedgerDeviceEntity? get connectedDevice => state.connectedDevice;

  @override
  Future<void> close() async {
    _logTeardown(await _disposeLedgerConnectionsUsecase.execute(), 'dispose');
    await super.close();
  }

  void _logTeardown(Result<void, LedgerFailure> result, String step) {
    result.fold(
      (_) {},
      (failure) => log.warning('Ledger $step failed: ${failure.runtimeType}'),
    );
  }

  /// Runs [operation] after scanning for and connecting to a device. Every step
  /// yields a typed [LedgerFailure] on error — nothing is thrown across this
  /// boundary and no raw text is ever stored in state.
  Future<void> executeOperation<T>(
    Future<Result<T, LedgerFailure>> Function() operation,
  ) async {
    if (state.connectedDevice != null) {
      _logTeardown(
        await _disconnectLedgerDeviceUsecase.execute(state.connectedDevice!),
        'disconnect',
      );
    }

    emit(state.copyWith(status: LedgerOperationStatus.scanning, failure: null));

    final List<LedgerDeviceEntity> devices;
    switch (await _scanLedgerDevicesUsecase.execute(
      deviceType: _requestedDeviceType,
    )) {
      case Ok(:final value):
        devices = value;
      case Err(:final failure):
        return _emitFailure(failure);
    }
    if (devices.isEmpty) {
      return _emitFailure(const LedgerNoDevicesFoundFailure());
    }

    emit(
      state.copyWith(
        status: LedgerOperationStatus.connecting,
        connectedDevice: devices.first,
      ),
    );

    switch (await _connectLedgerDeviceUsecase.execute(devices.first)) {
      case Ok():
        break;
      case Err(:final failure):
        return _emitFailure(failure);
    }

    emit(state.copyWith(status: LedgerOperationStatus.processing));

    switch (await operation()) {
      case Ok(:final value):
        emit(
          state.copyWith(status: LedgerOperationStatus.success, result: value),
        );
      case Err(:final failure):
        _emitFailure(failure);
    }
  }

  void _emitFailure(LedgerFailure failure) {
    emit(state.copyWith(status: LedgerOperationStatus.error, failure: failure));
  }

  void reset() {
    emit(const LedgerOperationState());
  }
}
