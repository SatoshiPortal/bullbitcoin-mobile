import 'package:bb_mobile/core/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core/bitbox/domain/errors/bitbox_failure.dart';
import 'package:bb_mobile/core/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/connect_bitbox_device_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/scan_bitbox_devices_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bitbox/presentation/cubit/bitbox_operation_state.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BitBoxOperationCubit extends Cubit<BitBoxOperationState> {
  final ScanBitBoxDevicesUsecase _scanBitBoxDevicesUsecase;
  final ConnectBitBoxDeviceUsecase _connectBitBoxDeviceUsecase;
  final BitBoxDeviceRepository _repository;
  bool _isDisposed = false;
  bool _isExecuting = false;

  BitBoxOperationCubit({
    required this._scanBitBoxDevicesUsecase,
    required this._connectBitBoxDeviceUsecase,
  }) : _repository = locator<BitBoxDeviceRepository>(),
       super(const BitBoxOperationState());

  BitBoxDeviceEntity? get connectedDevice => state.connectedDevice;

  void showPairingCode(String pairingCode) {
    _emitIfActive(
      state.copyWith(
        status: BitBoxOperationStatus.showingPairingCode,
        result: 'Pairing code:\n$pairingCode',
      ),
    );
  }

  void showAddressVerification(String address) {
    _emitIfActive(
      state.copyWith(
        status: BitBoxOperationStatus.showingAddressVerification,
        result: address,
      ),
    );
  }

  void showWaitingForPassword() {
    _emitIfActive(
      state.copyWith(
        status: BitBoxOperationStatus.waitingForPassword,
        failure: null,
      ),
    );
  }

  void showProcessing() {
    _emitIfActive(
      state.copyWith(status: BitBoxOperationStatus.processing, failure: null),
    );
  }

  @override
  Future<void> close() async {
    _isDisposed = true;

    await _repository.dispose();
    await super.close();
  }

  Future<void> executeOperation(
    Future<Result<Object?, BitBoxFailure>> Function() operation,
  ) async {
    if (_isDisposed || _isExecuting) return;
    _isExecuting = true;

    try {
      if (state.connectedDevice == null) {
        _emitIfActive(
          state.copyWith(status: BitBoxOperationStatus.scanning, failure: null),
        );

        final BitBoxDeviceEntity device;
        switch (await _scanBitBoxDevicesUsecase.execute()) {
          case Err(:final failure):
            await _fail(failure);
            return;
          case Ok(:final value):
            if (_isDisposed) return;
            device = value.first;
        }

        _emitIfActive(
          state.copyWith(
            status: BitBoxOperationStatus.connecting,
            connectedDevice: device,
          ),
        );

        if (await _connectBitBoxDeviceUsecase.execute(device) case Err(
          :final failure,
        )) {
          if (_isDisposed) return;
          await _fail(failure);
          return;
        }
        if (_isDisposed) {
          await _disconnectDevice(device);
          return;
        }
      }

      switch (await operation()) {
        case Ok(:final value):
          if (_isDisposed) return;
          _emitIfActive(
            state.copyWith(
              status: BitBoxOperationStatus.success,
              result: value,
            ),
          );
        case Err(:final failure):
          if (_isDisposed) return;
          await _fail(failure);
      }
    } finally {
      _isExecuting = false;
    }
  }

  Future<void> _fail(BitBoxFailure failure) async {
    await _disconnectIfConnected();
    if (_isDisposed) return;
    _emitIfActive(
      state.copyWith(
        status: BitBoxOperationStatus.error,
        connectedDevice: null,
        failure: failure,
      ),
    );
  }

  Future<void> _disconnectIfConnected() async {
    final BitBoxDeviceEntity? device = state.connectedDevice;
    if (device == null) return;
    await _disconnectDevice(device);
  }

  Future<void> _disconnectDevice(BitBoxDeviceEntity device) async {
    await _repository.disconnectConnection(device);
  }

  void reset() {
    _emitIfActive(const BitBoxOperationState());
  }

  void _emitIfActive(BitBoxOperationState nextState) {
    if (_isDisposed || isClosed) return;
    emit(nextState);
  }
}
