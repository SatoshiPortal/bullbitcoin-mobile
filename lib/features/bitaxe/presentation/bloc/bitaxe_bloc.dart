import 'dart:async';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/bitaxe/application/usecases/connect_to_device_usecase.dart';
import 'package:bb_mobile/features/bitaxe/application/usecases/get_stored_connection_usecase.dart';
import 'package:bb_mobile/features/bitaxe/application/usecases/get_system_info_usecase.dart';
import 'package:bb_mobile/features/bitaxe/application/usecases/identify_device_usecase.dart';
import 'package:bb_mobile/features/bitaxe/application/usecases/remove_connection_usecase.dart';
import 'package:bb_mobile/features/bitaxe/domain/errors/bitaxe_domain_error.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bitaxe_event.dart';
import 'bitaxe_state.dart';

class BitaxeBloc extends Bloc<BitaxeEvent, BitaxeState> {
  final ConnectToDeviceUsecase _connectToDeviceUsecase;
  final GetStoredConnectionUsecase _getStoredConnectionUsecase;
  final RemoveConnectionUsecase _removeConnectionUsecase;
  final GetSystemInfoUsecase _getSystemInfoUsecase;
  final IdentifyDeviceUsecase _identifyDeviceUsecase;

  Timer? _pollingTimer;

  BitaxeBloc({
    required ConnectToDeviceUsecase connectToDeviceUsecase,
    required GetStoredConnectionUsecase getStoredConnectionUsecase,
    required RemoveConnectionUsecase removeConnectionUsecase,
    required GetSystemInfoUsecase getSystemInfoUsecase,
    required IdentifyDeviceUsecase identifyDeviceUsecase,
  }) : _connectToDeviceUsecase = connectToDeviceUsecase,
       _getStoredConnectionUsecase = getStoredConnectionUsecase,
       _removeConnectionUsecase = removeConnectionUsecase,
       _getSystemInfoUsecase = getSystemInfoUsecase,
       _identifyDeviceUsecase = identifyDeviceUsecase,
       super(const BitaxeState()) {
    on<ConnectToDevice>(_onConnectToDevice);
    on<StartPolling>(_onStartPolling);
    on<StopPolling>(_onStopPolling);
    on<RefreshSystemInfo>(_onRefreshSystemInfo);
    on<IdentifyDevice>(_onIdentifyDevice);
    on<ClearError>(_onClearError);
    on<LoadStoredConnection>(_onLoadStoredConnection);
    on<RemoveConnection>(_onRemoveConnection);
  }

  Future<void> _onConnectToDevice(
    ConnectToDevice event,
    Emitter<BitaxeState> emit,
  ) async {
    emit(
      state.copyWith(
        isConnecting: true,
        error: null,
        currentStep: ConnectionStep.testingConnection,
      ),
    );

    try {
      final device = await _connectToDeviceUsecase.execute(
        ipAddress: event.ipAddress,
        wallet: event.wallet,
      );

      // Wait for 8 seconds to simulate the device being connected
      await Future.delayed(const Duration(seconds: 8));

      emit(
        state.copyWith(
          device: device,
          isConnecting: false,
          currentStep: ConnectionStep.completed,
        ),
      );
    } on BitaxeDomainError catch (e) {
      log.severe('Error connecting to device: $e');
      emit(state.copyWith(isConnecting: false, error: e, currentStep: null));
    } catch (e) {
      log.severe('Unexpected error connecting to device: $e');
      emit(
        state.copyWith(
          isConnecting: false,
          error: UnexpectedBitaxeError(e.toString()),
          currentStep: null,
        ),
      );
    }
  }

  Future<void> _getSystemInfo(Emitter<BitaxeState> emit) async {
    final device = state.device;
    if (device == null) {
      log.warning('Cannot get system info: device is null');
      return;
    }

    // Check if polling should continue
    if (!state.isPolling) {
      log.warning('Cannot get system info: polling stopped');
      return;
    }

    try {
      log.info('Getting system info for device at ${device.ipAddress}');
      emit(state.copyWith(isLoadingSystemInfo: true));
      final systemInfo = await _getSystemInfoUsecase.execute(device.ipAddress);

      emit(
        state.copyWith(
          device: device.copyWith(systemInfo: systemInfo),
          isLoadingSystemInfo: false,
          error: null,
        ),
      );
      log.info('Successfully got system info');
    } on BitaxeDomainError catch (e) {
      log.severe('Error getting system info: $e');
      emit(state.copyWith(isLoadingSystemInfo: false, error: e));
    } catch (e) {
      log.severe('Unexpected error getting system info: $e');
      emit(
        state.copyWith(
          isLoadingSystemInfo: false,
          error: UnexpectedBitaxeError(e.toString()),
        ),
      );
    }
  }

  Future<void> _onStartPolling(
    StartPolling event,
    Emitter<BitaxeState> emit,
  ) async {
    if (state.device == null) return;

    emit(state.copyWith(isPolling: true));

    // Poll immediately
    await _getSystemInfo(emit);

    // Then poll every 3 seconds by dispatching events
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      // Dispatch event instead of calling method directly
      // This ensures the emit function is fresh for each poll
      add(const BitaxeEvent.refreshSystemInfo());
    });
  }

  Future<void> _onStopPolling(
    StopPolling event,
    Emitter<BitaxeState> emit,
  ) async {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    emit(state.copyWith(isPolling: false));
  }

  Future<void> _onRefreshSystemInfo(
    RefreshSystemInfo event,
    Emitter<BitaxeState> emit,
  ) async {
    // Only poll if we have a device and polling is active
    if (state.device == null || !state.isPolling) {
      log.warning('Skipping refresh: device is null or polling is not active');
      return;
    }
    await _getSystemInfo(emit);
  }

  Future<void> _onIdentifyDevice(
    IdentifyDevice event,
    Emitter<BitaxeState> emit,
  ) async {
    final device = state.device;
    if (device == null) return;

    try {
      await _identifyDeviceUsecase.execute(device.ipAddress);
      log.info('Device identified successfully');
    } on BitaxeDomainError catch (e) {
      log.severe('Error identifying device: $e');
      emit(state.copyWith(error: e));
    } catch (e) {
      log.severe('Unexpected error identifying device: $e');
      emit(state.copyWith(error: UnexpectedBitaxeError(e.toString())));
    }
  }

  Future<void> _onLoadStoredConnection(
    LoadStoredConnection event,
    Emitter<BitaxeState> emit,
  ) async {
    try {
      // Try to load stored connection with fresh SystemInfo
      final device = await _getStoredConnectionUsecase.execute(
        fetchSystemInfo: true,
      );

      if (device != null) {
        emit(state.copyWith(device: device, error: null));
      } else {
        // No stored connection - emit state to signal check is complete
        // This ensures the listener fires and can navigate to connection screen
        emit(state.copyWith(device: null, error: null));
      }
    } on BitaxeDomainError catch (e) {
      log.severe('Error loading stored connection: $e');
      emit(state.copyWith(device: null, error: e));
    } catch (e) {
      log.severe('Error loading stored connection: $e');
      // Try loading without SystemInfo if fetch fails (e.g. storage errors)
      final deviceWithoutInfo = await _getStoredConnectionUsecase.execute(
        fetchSystemInfo: false,
      );
      if (deviceWithoutInfo != null) {
        emit(
          state.copyWith(
            device: deviceWithoutInfo,
            error: null, // Don't show error if we can at least load the device
          ),
        );
      } else {
        emit(
          state.copyWith(
            device: null,
            error: UnexpectedBitaxeError(e.toString()),
          ),
        );
      }
    }
  }

  Future<void> _onRemoveConnection(
    RemoveConnection event,
    Emitter<BitaxeState> emit,
  ) async {
    try {
      // Set loading state
      emit(state.copyWith(isRemovingConnection: true));

      // Stop polling first
      _pollingTimer?.cancel();
      _pollingTimer = null;

      // Remove stored connection
      await _removeConnectionUsecase.execute();

      // Clear device from state and reset loading state
      emit(
        state.copyWith(
          device: null,
          isPolling: false,
          isRemovingConnection: false,
          error: null,
        ),
      );

      log.info('Bitaxe connection removed successfully');
    } on BitaxeDomainError catch (e) {
      log.severe('Error removing connection: $e');
      emit(state.copyWith(isRemovingConnection: false, error: e));
    } catch (e) {
      log.severe('Unexpected error removing connection: $e');
      emit(
        state.copyWith(
          isRemovingConnection: false,
          error: UnexpectedBitaxeError(e.toString()),
        ),
      );
    }
  }

  Future<void> _onClearError(
    ClearError event,
    Emitter<BitaxeState> emit,
  ) async {
    emit(state.copyWith(error: null));
  }

  @override
  Future<void> close() {
    _pollingTimer?.cancel();
    return super.close();
  }
}
