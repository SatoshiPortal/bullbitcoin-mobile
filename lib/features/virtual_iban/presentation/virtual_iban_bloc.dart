import 'dart:async';

import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/entity/virtual_iban_recipient.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/create_virtual_iban_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_virtual_iban_details_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/virtual_iban/domain/virtual_iban_location.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'virtual_iban_event.dart';
part 'virtual_iban_state.dart';
part 'virtual_iban_bloc.freezed.dart';

class VirtualIbanBloc extends Bloc<VirtualIbanEvent, VirtualIbanState> {
  VirtualIbanBloc({
    required GetVirtualIbanDetailsUsecase getVirtualIbanDetailsUsecase,
    required CreateVirtualIbanUsecase createVirtualIbanUsecase,
    required GetExchangeUserSummaryUsecase getExchangeUserSummaryUsecase,
    required VirtualIbanLocation location,
  }) : _getVirtualIbanDetailsUsecase = getVirtualIbanDetailsUsecase,
       _createVirtualIbanUsecase = createVirtualIbanUsecase,
       _getExchangeUserSummaryUsecase = getExchangeUserSummaryUsecase,
       _location = location,
       super(const VirtualIbanState.initial()) {
    on<VirtualIbanStarted>(_onStarted);
    on<VirtualIbanNameConfirmationToggled>(_onNameConfirmationToggled);
    on<VirtualIbanCreateRequested>(_onCreateRequested);
    on<VirtualIbanRefreshRequested>(_onRefreshRequested);
    on<VirtualIbanPollingTicked>(_onPollingTicked);
  }

  final GetVirtualIbanDetailsUsecase _getVirtualIbanDetailsUsecase;
  final CreateVirtualIbanUsecase _createVirtualIbanUsecase;
  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;
  final VirtualIbanLocation _location;

  Timer? _pollingTimer;
  static const _pollingInterval = Duration(seconds: 5);

  VirtualIbanLocation get location => _location;

  @override
  Future<void> close() {
    _stopPolling();
    return super.close();
  }

  void _startPolling() {
    _stopPolling();
    _pollingTimer = Timer.periodic(_pollingInterval, (_) {
      add(const VirtualIbanEvent.pollingTicked());
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _onStarted(
    VirtualIbanStarted event,
    Emitter<VirtualIbanState> emit,
  ) async {
    emit(const VirtualIbanState.loading());

    try {
      // First get user summary for name display
      final userSummary = await _getExchangeUserSummaryUsecase.execute();

      // Then check VIBAN status
      final viban = await _getVirtualIbanDetailsUsecase.execute();

      if (viban == null) {
        // No VIBAN created yet
        emit(
          VirtualIbanState.notSubmitted(
            userSummary: userSummary,
            location: _location,
          ),
        );
      } else if (viban.isActive) {
        // VIBAN is fully activated
        emit(
          VirtualIbanState.active(
            recipient: viban,
            userSummary: userSummary,
            location: _location,
          ),
        );
      } else {
        // VIBAN exists but not yet activated - start polling
        emit(
          VirtualIbanState.pending(
            recipient: viban,
            userSummary: userSummary,
            location: _location,
          ),
        );
        _startPolling();
      }
    } on ApiKeyException catch (e) {
      emit(VirtualIbanState.error(exception: e));
    } on GetVirtualIbanDetailsException catch (e) {
      emit(VirtualIbanState.error(exception: e));
    } on GetExchangeUserSummaryException catch (e) {
      emit(VirtualIbanState.error(exception: e));
    } catch (e) {
      log.severe('Error starting VirtualIbanBloc: $e');
      emit(VirtualIbanState.error(exception: Exception('$e')));
    }
  }

  void _onNameConfirmationToggled(
    VirtualIbanNameConfirmationToggled event,
    Emitter<VirtualIbanState> emit,
  ) {
    final currentState = state;
    if (currentState is VirtualIbanNotSubmittedState) {
      emit(currentState.copyWith(nameConfirmed: event.confirmed));
    }
  }

  Future<void> _onCreateRequested(
    VirtualIbanCreateRequested event,
    Emitter<VirtualIbanState> emit,
  ) async {
    final currentState = state;
    if (currentState is! VirtualIbanNotSubmittedState) return;

    emit(currentState.copyWith(isCreating: true, error: null));

    try {
      final viban = await _createVirtualIbanUsecase.execute();

      if (viban.isActive) {
        // Immediately activated (rare but possible)
        emit(
          VirtualIbanState.active(
            recipient: viban,
            userSummary: currentState.userSummary,
            location: _location,
          ),
        );
      } else {
        // VIBAN created but pending activation - start polling
        emit(
          VirtualIbanState.pending(
            recipient: viban,
            userSummary: currentState.userSummary,
            location: _location,
          ),
        );
        _startPolling();
      }
    } on CreateVirtualIbanException catch (e) {
      emit(currentState.copyWith(isCreating: false, error: e));
    } catch (e) {
      log.severe('Error creating Virtual IBAN: $e');
      emit(currentState.copyWith(isCreating: false, error: Exception('$e')));
    }
  }

  Future<void> _onRefreshRequested(
    VirtualIbanRefreshRequested event,
    Emitter<VirtualIbanState> emit,
  ) async {
    // Re-trigger the started flow to refresh state
    add(const VirtualIbanEvent.started());
  }

  Future<void> _onPollingTicked(
    VirtualIbanPollingTicked event,
    Emitter<VirtualIbanState> emit,
  ) async {
    final currentState = state;
    if (currentState is! VirtualIbanPendingState) {
      _stopPolling();
      return;
    }

    try {
      final viban = await _getVirtualIbanDetailsUsecase.execute();

      if (viban != null && viban.isActive) {
        // VIBAN is now activated
        _stopPolling();
        emit(
          VirtualIbanState.active(
            recipient: viban,
            userSummary: currentState.userSummary,
            location: _location,
          ),
        );
      }
      // If still pending, just continue polling (no state change needed)
    } catch (e) {
      log.warning('Error during VIBAN polling: $e');
      // Continue polling even on error
    }
  }
}

