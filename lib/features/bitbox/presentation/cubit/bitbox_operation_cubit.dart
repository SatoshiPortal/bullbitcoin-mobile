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

  BitBoxOperationCubit({
    required ScanBitBoxDevicesUsecase scanBitBoxDevicesUsecase,
    required ConnectBitBoxDeviceUsecase connectBitBoxDeviceUsecase,
  }) : _scanBitBoxDevicesUsecase = scanBitBoxDevicesUsecase,
       _connectBitBoxDeviceUsecase = connectBitBoxDeviceUsecase,
       _repository = locator<BitBoxDeviceRepository>(),
       super(const BitBoxOperationState());

  BitBoxDeviceEntity? get connectedDevice => state.connectedDevice;

  void showPairingCode(String pairingCode) {
    emit(
      state.copyWith(
        status: BitBoxOperationStatus.showingPairingCode,
        result: 'Pairing code:\n$pairingCode',
      ),
    );
  }

  void showAddressVerification(String address) {
    emit(
      state.copyWith(
        status: BitBoxOperationStatus.showingAddressVerification,
        result: address,
      ),
    );
  }

  void showWaitingForPassword() {
    emit(
      state.copyWith(
        status: BitBoxOperationStatus.waitingForPassword,
        error: null,
      ),
    );
  }

  void showProcessing() {
    emit(
      state.copyWith(
        status: BitBoxOperationStatus.processing,
        error: null,
      ),
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
    try {
      if (state.connectedDevice == null) {
        emit(
          state.copyWith(
            status: BitBoxOperationStatus.scanning,
            error: null,
          ),
        );

        final BitBoxDeviceEntity device = await _pollForFirstDevice();

        emit(
          state.copyWith(
            status: BitBoxOperationStatus.connecting,
            connectedDevice: device,
          ),
        );

        await _connectBitBoxDeviceUsecase.execute(device);
      }

      try {
        final result = await operation();
        emit(
          state.copyWith(status: BitBoxOperationStatus.success, result: result),
        );
      } catch (e) {
        final interpretedMessage = _interpretErrorCode(e.toString());
        if (interpretedMessage != null) {
          throw BitBoxError.operationFailed(message: interpretedMessage);
        }
        throw BitBoxError.operationFailed(message: e.toString());
      }
    } on BitBoxError catch (e) {
      log.warning('BitBox operation failed: $e');
      emit(
        state.copyWith(
          status: BitBoxOperationStatus.error,
          error: e,
        ),
      );
      rethrow;
    } on Exception catch (e) {
      final interpretedMessage = _interpretErrorCode(e.toString());
      if (interpretedMessage != null) {
        log.warning('BitBox operation failed: $interpretedMessage');
        emit(
          state.copyWith(
            status: BitBoxOperationStatus.error,
            error: BitBoxError.operationFailed(message: interpretedMessage),
          ),
        );
      } else {
        log.warning('BitBox operation failed: $e');
        emit(
          state.copyWith(
            status: BitBoxOperationStatus.error,
            error: BitBoxError.operationFailed(message: e.toString()),
          ),
        );
      }

      rethrow;
    }
  }

  Future<void> disconnectIfConnected() async {
    final BitBoxDeviceEntity? device = state.connectedDevice;
    if (device == null) return;
    try {
      await _repository.disconnectConnection(device);
    } catch (_) {
      // Ignore disconnect errors during cleanup
    }
  }

  Future<BitBoxDeviceEntity> _pollForFirstDevice({
    Duration timeout = const Duration(seconds: 20),
    Duration interval = const Duration(milliseconds: 750),
  }) async {
    final DateTime start = DateTime.now();

    while (DateTime.now().difference(start) < timeout) {
      if (_isDisposed) {
        throw const BitBoxError.noDevicesFound();
      }

      try {
        final devices = await _scanBitBoxDevicesUsecase.execute();
        if (devices.isNotEmpty) {
          return devices.first;
        }
      } catch (_) {
        // Ignore transient scan errors and keep polling
      }
      
      if (_isDisposed) {
        throw const BitBoxError.noDevicesFound();
      }
      
      await Future.delayed(interval);
    }

    throw const BitBoxError.noDevicesFound();
  }

  void reset() {
    emit(const BitBoxOperationState());
  }
}

String? _interpretErrorCode(String error) {
  if (error.contains('permission denied') || error.contains('Permission denied')) {
    return 'USB permission denied. Please grant permission to access your BitBox device.';
  }
  
  if (error.contains('device not found') || error.contains('No devices found')) {
    return 'No BitBox device found. Please connect your device and try again.';
  }
  
  if (error.contains('device not paired') || error.contains('not paired')) {
    return 'Device not paired. Please complete the pairing process first.';
  }
  
  if (error.contains('handshake') || error.contains('Handshake')) {
    return 'Failed to establish secure connection. Please try again.';
  }
  
  if (error.contains('timeout') || error.contains('Timeout')) {
    return 'Operation timed out. Please try again.';
  }
  
  if (error.contains('connection failed') || error.contains('Connection failed')) {
    return 'Failed to connect to BitBox device. Please check your connection.';
  }
  
  if (error.contains('invalid response') || error.contains('Invalid response')) {
    return 'Invalid response from BitBox device. Please try again.';
  }
  
  if (error.contains('operation cancelled') || error.contains('Operation cancelled')) {
    return 'Operation was cancelled. Please try again.';
  }
  
  final lines = error.split('\n');
  if (lines.isNotEmpty) {
    final firstLine = lines.first.trim();
    if (firstLine.isNotEmpty && 
        !firstLine.startsWith('Exception:') && 
        !firstLine.contains('at ') &&
        !firstLine.startsWith('Error:') &&
        !firstLine.startsWith('Failed assertion:')) {
      return firstLine;
    }
  }
  
  return null;
}
