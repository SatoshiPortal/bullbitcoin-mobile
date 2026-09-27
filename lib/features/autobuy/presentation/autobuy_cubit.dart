import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/autobuy/domain/autobuy_failure.dart';
import 'package:bb_mobile/features/autobuy/domain/usecases/get_autobuy_status_usecase.dart';
import 'package:bb_mobile/features/autobuy/domain/usecases/set_autobuy_usecase.dart';
import 'package:bb_mobile/features/default_wallets/public/default_wallets_facade.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'autobuy_cubit.freezed.dart';
part 'autobuy_state.dart';

class AutoBuyCubit extends Cubit<AutoBuyState> {
  final SetAutoBuyUsecase _setAutoBuyUsecase;
  final GetAutoBuyStatusUsecase _getAutoBuyStatusUsecase;

  AutoBuyCubit(
    this._setAutoBuyUsecase,
    this._getAutoBuyStatusUsecase, {
    bool isActive = false,
    bool isRestricted = true,
  }) : super(AutoBuyState(isActive: isActive, isRestricted: isRestricted));

  Future<void> loadStatus() async {
    emit(state.copyWith(isLoadingStatus: true, failure: null));

    final result = await _getAutoBuyStatusUsecase.execute();
    if (isClosed) return;

    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            isLoadingStatus: false,
            isActive: value.isActive,
            isRestricted: value.isRestricted,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(isLoadingStatus: false, failure: failure));
    }
  }

  void showWallets() {
    emit(state.copyWith(step: AutoBuyStep.wallets, failure: null));
  }

  void showIntro() {
    emit(state.copyWith(step: AutoBuyStep.intro, failure: null));
  }

  void showConfirmation(DefaultWallets wallets) {
    emit(
      state.copyWith(
        step: AutoBuyStep.confirm,
        wallets: wallets,
        failure: null,
      ),
    );
  }

  void showWalletsFromConfirmation() {
    emit(state.copyWith(step: AutoBuyStep.wallets, failure: null));
  }

  Future<void> setEnabled(bool enabled) async {
    if (state.isSaving) return;

    emit(
      state.copyWith(
        isSaving: true,
        statusChangeSucceeded: false,
        failure: null,
      ),
    );

    final result = await _setAutoBuyUsecase.execute(enabled: enabled);
    if (isClosed) return;

    switch (result) {
      case Err(:final failure):
        emit(state.copyWith(isSaving: false, failure: failure));
      case Ok():
        await _confirmEnabled(enabled);
    }
  }

  /// A save that returns normally is not proof the account changed.
  Future<void> _confirmEnabled(bool enabled) async {
    final result = await _getAutoBuyStatusUsecase.execute();
    if (isClosed) return;

    switch (result) {
      case Ok(:final value) when value.isActive == enabled:
        emit(
          state.copyWith(
            isSaving: false,
            isActive: value.isActive,
            isRestricted: value.isRestricted,
            statusChangeSucceeded: true,
          ),
        );
      case Ok():
        emit(
          state.copyWith(
            isSaving: false,
            failure: const AutoBuyStatusUnconfirmedFailure(
              'account did not report the requested AutoBuy state',
            ),
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(isSaving: false, failure: failure));
    }
  }
}
