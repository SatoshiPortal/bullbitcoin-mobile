import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/errors/ledger_errors.dart';
import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/connect_ledger_device_usecase.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/scan_ledger_devices_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/ledger/presentation/cubit/ledger_operation_state.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LedgerOperationCubit extends Cubit<LedgerOperationState> {
  final ScanLedgerDevicesUsecase _scanLedgerDevicesUsecase;
  final ConnectLedgerDeviceUsecase _connectLedgerDeviceUsecase;
  final LedgerDeviceRepository _repository;
  final SignerDeviceEntity? _requestedDeviceType;

  LedgerOperationCubit({
    required ScanLedgerDevicesUsecase scanLedgerDevicesUsecase,
    required ConnectLedgerDeviceUsecase connectLedgerDeviceUsecase,
    SignerDeviceEntity? requestedDeviceType,
  }) : _scanLedgerDevicesUsecase = scanLedgerDevicesUsecase,
       _connectLedgerDeviceUsecase = connectLedgerDeviceUsecase,
       _repository = locator<LedgerDeviceRepository>(),
       _requestedDeviceType = requestedDeviceType,
       super(const LedgerOperationState());

  LedgerDeviceEntity? get connectedDevice => state.connectedDevice;

  @override
  Future<void> close() async {
    try {
      await _repository.dispose();
    } catch (e) {
      log.warning('Error disposing Ledger repository', error: e);
    }

    await super.close();
  }

  Future<void> executeOperation(Future<dynamic> Function() operation) async {
    try {
      if (state.connectedDevice != null) {
        await _repository.disconnectConnection(state.connectedDevice!);
      }

      emit(
        state.copyWith(
          status: LedgerOperationStatus.scanning,
          errorMessage: null,
        ),
      );
      final devices = await _scanLedgerDevicesUsecase.execute(deviceType: _requestedDeviceType);

      emit(
        state.copyWith(
          status: LedgerOperationStatus.connecting,
          connectedDevice: devices.first,
        ),
      );

      await _connectLedgerDeviceUsecase.execute(devices.first);

      emit(state.copyWith(status: LedgerOperationStatus.processing));

      try {
        final result = await operation();
        emit(
          state.copyWith(status: LedgerOperationStatus.success, result: result),
        );
      } catch (e) {
        final interpretedMessage = _interpretErrorCode(e.toString());
        if (interpretedMessage != null) {
          throw LedgerError.operationFailed(message: interpretedMessage);
        }
        throw LedgerError.operationFailed(message: e.toString());
      }
    } on LedgerError catch (e) {
      final message = e.message;
      log.severe('Ledger operation failed: $message');
      emit(
        state.copyWith(
          status: LedgerOperationStatus.error,
          errorMessage: message,
        ),
      );
      rethrow;
    } on Exception catch (e) {
      final interpretedMessage = _interpretErrorCode(e.toString());
      if (interpretedMessage != null) {
        log.severe('Ledger operation failed: $interpretedMessage');
        emit(
          state.copyWith(
            status: LedgerOperationStatus.error,
            errorMessage: interpretedMessage,
          ),
        );
      } else {
        log.severe('Ledger operation failed: $e');
        emit(
          state.copyWith(
            status: LedgerOperationStatus.error,
            errorMessage: e.toString(),
          ),
        );
      }
      rethrow;
    }
  }

  void reset() {
    emit(const LedgerOperationState());
  }
}

String? _interpretErrorCode(String error) {
  if (error.contains(
    "Make sure no other program is communicating with the Ledger",
  )) {
    return error;
  }

  final errorCodePatterns = {
    '6985': 'Transaction was rejected by the user on the Ledger device.',
    '5515': 'Ledger device is locked. Please unlock your device and try again.',
    '6e01': 'Please open the Bitcoin app on your Ledger device and try again.',
    '6a87': 'Please open the Bitcoin app on your Ledger device and try again.',
    '6d02': 'Please open the Bitcoin app on your Ledger device and try again.',
    '6511': 'Please open the Bitcoin app on your Ledger device and try again.',
    '6e00': 'Please open the Bitcoin app on your Ledger device and try again.',
  };

  final patterns = [
    RegExp(r'(?:0x\S*?|[0-9a-f]{4})(?= )'),
    RegExp('Exception:\\s*([0-9a-f]{4})'),
    RegExp('[0-9a-f]{4}'),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(error);
    if (match != null) {
      final errorCode =
          match.group(0)?.replaceAll("0x", "").replaceAll("Exception: ", "") ??
          "";

      for (final entry in errorCodePatterns.entries) {
        if (errorCode.contains(entry.key)) {
          return entry.value;
        }
      }
    }
  }

  return null;
}
