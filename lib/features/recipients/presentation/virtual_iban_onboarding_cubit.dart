import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/watch_virtual_iban_activation_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/virtual_iban_status.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'virtual_iban_onboarding_cubit.freezed.dart';
part 'virtual_iban_onboarding_state.dart';

class VirtualIbanOnboardingCubit extends Cubit<VirtualIbanOnboardingState> {
  final WatchVirtualIbanActivationUsecase _watchActivationUsecase;
  StreamSubscription<Result<VirtualIbanStatus, RecipientsFailure>>?
  _subscription;

  VirtualIbanOnboardingCubit(this._watchActivationUsecase)
    : super(const VirtualIbanOnboardingState());

  Future<void> load() => _watch(createIfAbsent: false);

  Future<void> activate() => _watch(createIfAbsent: true);

  void confirmationChanged(bool value) {
    emit(state.copyWith(isNameConfirmed: value));
  }

  Future<void> retry() =>
      _watch(createIfAbsent: state.status == VirtualIbanStatus.absent);

  Future<void> _watch({required bool createIfAbsent}) async {
    if (isClosed) return;
    await _subscription?.cancel();
    emit(
      state.copyWith(
        isLoading: true,
        isCreating: createIfAbsent,
        failure: null,
      ),
    );
    _subscription = _watchActivationUsecase
        .execute(createIfAbsent: createIfAbsent)
        .listen(_onResult, onDone: _onDone);
  }

  void _onResult(Result<VirtualIbanStatus, RecipientsFailure> result) {
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            status: value,
            isLoading: value == VirtualIbanStatus.pending,
            isCreating: value == VirtualIbanStatus.pending,
            failure: null,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(isLoading: false, isCreating: false, failure: failure),
        );
    }
  }

  void _onDone() {
    _subscription = null;
    if (isClosed || state.status == VirtualIbanStatus.pending) return;
    emit(state.copyWith(isLoading: false, isCreating: false));
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
