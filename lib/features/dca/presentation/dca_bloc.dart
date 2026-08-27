import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/dca/domain/dca.dart';
import 'package:bb_mobile/features/dca/domain/dca_failure.dart';
import 'package:bb_mobile/features/dca/domain/usecases/set_dca_usecase.dart';
import 'package:bb_mobile/features/dca/domain/usecases/start_dca_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dca_bloc.freezed.dart';
part 'dca_event.dart';
part 'dca_state.dart';

class DcaBloc extends Bloc<DcaEvent, DcaState> {
  DcaBloc({required this._startDcaUsecase, required this._setDcaUsecase})
    : super(const DcaState.initial()) {
    on<DcaStarted>(_onStarted);
    on<DcaBuyInputContinuePressed>(_onBuyInputContinuePressed);
    on<DcaWalletSelected>(_onWalletSelected);
    on<DcaConfirmed>(_onConfirmed);
  }

  final StartDcaUsecase _startDcaUsecase;
  final SetDcaUsecase _setDcaUsecase;

  Future<void> _onStarted(DcaStarted event, Emitter<DcaState> emit) async {
    emit(const DcaState.initial());
    final result = await _startDcaUsecase.execute();
    if (isClosed) return;

    switch (result) {
      case Ok(value: final startData):
        emit(
          DcaState.buyInput(
            balances: startData.balances,
            currency: startData.currency,
            defaultLightningAddress: startData.lightningAddress,
          ),
        );
      case Err(:final failure):
        emit(DcaState.initial(failure: failure));
    }
  }

  Future<void> _onBuyInputContinuePressed(
    DcaBuyInputContinuePressed event,
    Emitter<DcaState> emit,
  ) async {
    // We should be on a clean DcaBuyInputState state here
    final buyInputState = state.toCleanBuyInputState;
    if (buyInputState == null) {
      log.severe(
        error: 'Expected to be on DcaBuyInputState',
        trace: StackTrace.current,
      );
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
      log.severe(
        error: 'Expected to be on DcaWalletSelectionState',
        trace: StackTrace.current,
      );
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
      log.severe(
        error: 'Expected to be on DcaConfirmationState',
        trace: StackTrace.current,
      );
      return;
    }

    emit(dcaConfirmationState.copyWith(isConfirmingDca: true));

    final result = await _setDcaUsecase.execute(
      amount: dcaConfirmationState.amount,
      currency: dcaConfirmationState.currency,
      frequency: dcaConfirmationState.frequency,
      network: dcaConfirmationState.network,
      lightningAddress: dcaConfirmationState.lightningAddress,
    );
    if (isClosed) return;

    switch (result) {
      case Ok(value: final dca):
        emit(
          dcaConfirmationState.toSuccessState(
            amount: dca.amount,
            currency: dca.currency,
            frequency: dca.frequency,
          ),
        );
      case Err(:final failure):
        emit(
          dcaConfirmationState.copyWith(
            isConfirmingDca: false,
            failure: failure,
          ),
        );
    }
  }
}
