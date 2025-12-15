import 'dart:async';

import 'package:bb_mobile/core_deprecated/errors/exchange_errors.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/usecases/save_user_preferences_usecase.dart';
import 'package:bb_mobile/core_deprecated/utils/logger.dart' show log;
import 'package:bb_mobile/features/dca/domain/dca.dart';
import 'package:bb_mobile/features/dca/domain/usecases/set_dca_usecase.dart';
import 'package:bb_mobile/features/dca/domain/usecases/start_dca_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dca_bloc.freezed.dart';
part 'dca_event.dart';
part 'dca_state.dart';

class DcaBloc extends Bloc<DcaEvent, DcaState> {
  DcaBloc({
    required StartDcaUsecase startDcaUsecase,
    required SetDcaUsecase setDcaUsecase,
    required SaveUserPreferencesUsecase saveUserPreferencesUsecase,
  }) : _startDcaUsecase = startDcaUsecase,
       _setDcaUsecase = setDcaUsecase,
       _saveUserPreferencesUsecase = saveUserPreferencesUsecase,
       super(const DcaState.initial()) {
    on<DcaStarted>(_onStarted);
    on<DcaBuyInputContinuePressed>(_onBuyInputContinuePressed);
    on<DcaWalletSelected>(_onWalletSelected);
    on<DcaConfirmed>(_onConfirmed);
  }

  final StartDcaUsecase _startDcaUsecase;
  final SetDcaUsecase _setDcaUsecase;
  final SaveUserPreferencesUsecase _saveUserPreferencesUsecase;

  Future<void> _onStarted(DcaStarted event, Emitter<DcaState> emit) async {
    try {
      final startData = await _startDcaUsecase.execute();

      emit(
        DcaState.buyInput(
          balances: startData.balances,
          currency: startData.currency,
          defaultLightningAddress: startData.lightningAddress,
        ),
      );
    } on ApiKeyException catch (e) {
      emit(DcaState.initial(apiKeyException: e));
    } on GetExchangeUserSummaryException catch (e) {
      emit(DcaState.initial(getUserSummaryException: e));
    }
  }

  Future<void> _onBuyInputContinuePressed(
    DcaBuyInputContinuePressed event,
    Emitter<DcaState> emit,
  ) async {
    // We should be on a clean DcaBuyInputState state here
    final buyInputState = state.toCleanBuyInputState;
    if (buyInputState == null) {
      log.severe('Expected to be on DcaBuyInputState but on: $state');
      return;
    }
    emit(buyInputState);

    emit(
      buyInputState.toWalletSelectionState(
        amount: double.parse(event.amountInput),
        currency: event.currency,
        frequency: event.frequency,
      ),
    );
  }

  Future<void> _onWalletSelected(
    DcaWalletSelected event,
    Emitter<DcaState> emit,
  ) async {
    // We should be on a clean DcaWalletSelectionState state here
    final walletSelectionState = state.toCleanWalletSelectionState;
    if (walletSelectionState == null) {
      log.severe('Expected to be on DcaWalletSelectionState but on: $state');
      return;
    }
    emit(walletSelectionState);

    emit(
      walletSelectionState.toConfirmationState(
        network: event.network,
        lightningAddress: event.lightningAddress,
        isDefaultLightningAddress: event.useDefaultLightningAddress ?? false,
      ),
    );
  }

  Future<void> _onConfirmed(DcaConfirmed event, Emitter<DcaState> emit) async {
    // We should be on a DcaConfirmationState here
    final dcaConfirmationState = state.toCleanConfirmationState;
    if (dcaConfirmationState == null) {
      log.severe('Expected to be on DcaConfirmationState but on: $state');
      return;
    }

    emit(dcaConfirmationState.copyWith(isConfirmingDca: true));
    try {
      final dca = await _setDcaUsecase.execute(
        amount: dcaConfirmationState.amount,
        currency: dcaConfirmationState.currency,
        frequency: dcaConfirmationState.frequency,
        network: dcaConfirmationState.network,
        lightningAddress: dcaConfirmationState.lightningAddress,
      );

      // Now that the configuration was stored successfully,
      // We can activate DCA again.
      await _saveUserPreferencesUsecase.execute(dcaEnabled: true);

      emit(
        dcaConfirmationState.toSuccessState(
          amount: dca.amount,
          currency: dca.currency,
          frequency: dca.frequency,
        ),
      );
    } catch (e) {
      // Log unexpected errors
      emit(dcaConfirmationState.copyWith(error: e));
      log.severe('Unexpected error in DcaBloc: $e');
    } finally {
      if (state is DcaConfirmationState) {
        emit((state as DcaConfirmationState).copyWith(isConfirmingDca: false));
      }
    }
  }
}
