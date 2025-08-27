import 'dart:async';

import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart' hide Network;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dca_bloc.freezed.dart';
part 'dca_event.dart';
part 'dca_state.dart';

class DcaBloc extends Bloc<DcaEvent, DcaState> {
  DcaBloc({
    required GetExchangeUserSummaryUsecase getExchangeUserSummaryUsecase,
  }) : _getExchangeUserSummaryUsecase = getExchangeUserSummaryUsecase,

       super(const DcaState.initial()) {
    on<DcaStarted>(_onStarted);
    on<DcaAmountInputContinuePressed>(_onAmountInputContinuePressed);
    on<DcaWalletSelected>(_onWalletSelected);
    on<DcaConfirmed>(_onConfirmed);
  }

  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;

  Future<void> _onStarted(DcaStarted event, Emitter<DcaState> emit) async {
    try {
      final userSummary = await _getExchangeUserSummaryUsecase.execute();

      emit(DcaState.amountInput(userSummary: userSummary));
    } on ApiKeyException catch (e) {
      emit(DcaState.initial(apiKeyException: e));
    } on GetExchangeUserSummaryException catch (e) {
      emit(DcaState.initial(getUserSummaryException: e));
    }
  }

  Future<void> _onAmountInputContinuePressed(
    DcaAmountInputContinuePressed event,
    Emitter<DcaState> emit,
  ) async {
    // We should be on a clean DcaWalletSelectionState state here
    final amountInputState = state.toCleanAmountInputState;
    if (amountInputState == null) {
      log.severe('Expected to be on DcaAmountInputState but on: $state');
      return;
    }
    emit(amountInputState);

    emit(
      amountInputState.toWalletSelectionState(
        amount: double.parse(event.amountInput),
        currency: event.currency,
      ),
    );
  }

  Future<void> _onWalletSelected(
    DcaWalletSelected event,
    Emitter<DcaState> emit,
  ) async {
    final walletSelectionState = state.toCleanWalletSelectionState;
    if (walletSelectionState == null) {
      log.severe('Expected to be on DcaWalletSelectionState but on: $state');
      return;
    }
  }

  Future<void> _onConfirmed(DcaConfirmed event, Emitter<DcaState> emit) async {
    // We should be on a DcaConfirmationState
    final dcaConfirmationState = state.toCleanConfirmationState;
    if (dcaConfirmationState == null) {
      log.severe('Expected to be on DcaConfirmationState but on: $state');
      return;
    }

    emit(dcaConfirmationState.copyWith(isConfirmingDca: true));
    try {} catch (e) {
      // Log unexpected errors
      log.severe('Unexpected error in DcaBloc: $e');
    } finally {
      if (state is DcaConfirmationState) {
        emit((state as DcaConfirmationState).copyWith(isConfirmingDca: false));
      }
    }
  }
}
