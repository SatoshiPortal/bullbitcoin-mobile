import 'package:bb_mobile/core/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core/bitbox/domain/errors/bitbox_errors.dart';
import 'package:bb_mobile/core/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/connect_bitbox_device_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/scan_bitbox_devices_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
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
        error: null,
      ),
    );
  }

  void showProcessing() {
    _emitIfActive(
      state.copyWith(status: BitBoxOperationStatus.processing, error: null),
    );
  }

  @override
  Future<void> close() async {
    _isDisposed = true;

    try {
      await _repository.dispose();
    } catch (e) {
      log.warning('Error disposing BitBox repository', error: e);
    }

    await super.close();
  }

  Future<void> executeOperation(Future<dynamic> Function() operation) async {
    if (_isDisposed || _isExecuting) return;
    _isExecuting = true;

    try {
      if (state.connectedDevice == null) {
        _emitIfActive(
          state.copyWith(status: BitBoxOperationStatus.scanning, error: null),
        );

        final devices = await _scanBitBoxDevicesUsecase.execute();
        if (_isDisposed) return;
        if (devices.isEmpty) {
          throw const BitBoxError.noDevicesFound();
        }
        final BitBoxDeviceEntity device = devices.first;

        _emitIfActive(
          state.copyWith(
            status: BitBoxOperationStatus.connecting,
            connectedDevice: device,
          ),
        );

        await _connectBitBoxDeviceUsecase.execute(device);
        if (_isDisposed) {
          await _disconnectDevice(device);
          return;
        }
      }

      try {
        final result = await operation();
        if (_isDisposed) return;

        _emitIfActive(
          state.copyWith(status: BitBoxOperationStatus.success, result: result),
        );
      } catch (e) {
        if (e is BitBoxError) rethrow;
        throw BitBoxError.operationFailed(message: e.toString());
      }
    } on BitBoxError catch (e) {
      final error = e is OperationFailedBitBoxError
          ? _interpretError(e.message) ?? e
          : e;
      if (_isDisposed) return;

      await _disconnectIfConnected();
      if (_isDisposed) return;

      _emitIfActive(
        state.copyWith(
          status: BitBoxOperationStatus.error,
          connectedDevice: null,
          error: error,
        ),
      );
      throw error;
    } on Exception catch (e) {
      if (_isDisposed) return;

      await _disconnectIfConnected();
      if (_isDisposed) return;

      final interpretedError = _interpretError(e.toString());
      if (interpretedError != null) {
        _emitIfActive(
          state.copyWith(
            status: BitBoxOperationStatus.error,
            connectedDevice: null,
            error: interpretedError,
          ),
        );
      } else {
        _emitIfActive(
          state.copyWith(
            status: BitBoxOperationStatus.error,
            connectedDevice: null,
            error: BitBoxError.operationFailed(message: e.toString()),
          ),
        );
      }

      rethrow;
    } finally {
      _isExecuting = false;
    }
  }

  Future<void> _disconnectIfConnected() async {
    final BitBoxDeviceEntity? device = state.connectedDevice;
    if (device == null) return;
    await _disconnectDevice(device);
  }

  Future<void> _disconnectDevice(BitBoxDeviceEntity device) async {
    try {
      await _repository.disconnectConnection(device);
    } catch (_) {
      // Ignore disconnect errors during cleanup
    }
  }

  void reset() {
    _emitIfActive(const BitBoxOperationState());
  }

  void _emitIfActive(BitBoxOperationState nextState) {
    if (_isDisposed || isClosed) return;
    emit(nextState);
  }
}

BitBoxError? _interpretError(String error) {
  final normalized = error.toLowerCase();

  if (normalized.contains('permission denied')) {
    return const BitBoxError.permissionDenied();
  }

  if (normalized.contains('no devices found')) {
    return const BitBoxError.noDevicesFound();
  }

  if (normalized.contains('device not found')) {
    return const BitBoxError.deviceNotFound();
  }

  if (normalized.contains('device not paired') ||
      normalized.contains('not paired')) {
    return const BitBoxError.deviceNotPaired();
  }

  if (normalized.contains('handshake')) {
    return const BitBoxError.handshakeFailed();
  }

  if (normalized.contains('timeout')) {
    return const BitBoxError.operationTimeout();
  }

  if (normalized.contains('connection failed')) {
    return const BitBoxError.connectionFailed();
  }

  if (normalized.contains('invalid response')) {
    return const BitBoxError.invalidResponse();
  }

  if (normalized.contains('operation cancelled')) {
    return const BitBoxError.operationCancelled();
  }

  return null;
}
