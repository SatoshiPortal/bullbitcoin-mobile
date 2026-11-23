import 'dart:async';

import 'package:exchange/exchange.dart';
import 'package:bull_logger/bull_logger.dart' show log;
import 'package:primitives/primitives.dart';
import 'package:bull_exchange/src/dca/domain/dca_failure.dart';
import 'package:bull_exchange/src/dca/domain/usecases/get_dca_default_wallets_usecase.dart';
import 'package:bull_exchange/src/dca/domain/usecases/set_dca_usecase.dart';
import 'package:bull_exchange/src/dca/domain/usecases/start_dca_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dca_bloc.freezed.dart';
part 'dca_event.dart';
part 'dca_state.dart';

class DcaBloc extends Bloc<DcaEvent, DcaState> {
  DcaBloc({
    required this._startDcaUsecase,
    required this._getDcaDefaultWalletsUsecase,
    required this._setDcaUsecase,
  }) : super(const DcaState.initial()) {
    on<DcaStarted>(_onStarted);
    on<DcaBuyInputContinuePressed>(_onBuyInputContinuePressed);
    on<DcaWalletSelected>(_onWalletSelected);
    on<DcaDefaultWalletsRefreshRequested>(_onDefaultWalletsRefreshRequested);
    on<DcaConfirmed>(_onConfirmed);
  }

  final StartDcaUsecase _startDcaUsecase;
  final GetDcaDefaultWalletsUsecase _getDcaDefaultWalletsUsecase;
  final SetDcaUsecase _setDcaUsecase;

  Future<void> _onStarted(DcaStarted event, Emitter<DcaState> emit) async {
    emit(const DcaState.initial());
    final result = await _startDcaUsecase.execute();
    if (isClosed) return;

    final DcaStartData startData;
    switch (result) {
      case Ok(:final value):
        startData = value;
      case Err(:final failure):
        emit(DcaState.initial(failure: failure));
        return;
    }

    final walletsResult = await _getDcaDefaultWalletsUsecase.execute();
    if (isClosed) return;

    switch (walletsResult) {
      case Ok(value: final defaultWallets):
        emit(
          DcaState.buyInput(
            balances: startData.balances,
            currency: startData.currency,
            defaultLightningAddress: startData.lightningAddress,
            defaultWallets: defaultWallets,
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
        address: event.address,
        isDefaultAddress: event.isDefaultAddress,
      ),
    );
  }

  /// Re-reads the exchange default wallets after the user came back from the
  /// default wallets editor. Only the wallet-selection step shows them, so a
  /// result that arrives after the user left that step is dropped.
  Future<void> _onDefaultWalletsRefreshRequested(
    DcaDefaultWalletsRefreshRequested event,
    Emitter<DcaState> emit,
  ) async {
    if (state is! DcaWalletSelectionState) return;

    final result = await _getDcaDefaultWalletsUsecase.execute();
    if (isClosed) return;

    final current = state;
    if (current is! DcaWalletSelectionState) return;
    // On a failed read the wallets shown stay as they were; the user can still
    // type an address or open the editor again.
    if (result case Ok(value: final defaultWallets)) {
      emit(current.copyWith(defaultWallets: defaultWallets));
    }
  }

  Future<void> _onConfirmed(DcaConfirmed event, Emitter<DcaState> emit) async {
    if (state case DcaConfirmationState(isConfirmingDca: true)) return;
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
      address: dcaConfirmationState.address,
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
