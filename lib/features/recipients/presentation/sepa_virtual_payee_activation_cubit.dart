import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/watch_sepa_virtual_payee_activation_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/entities/sepa_virtual_payee_status.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sepa_virtual_payee_activation_cubit.freezed.dart';
part 'sepa_virtual_payee_activation_state.dart';

class SepaVirtualPayeeActivationCubit
    extends Cubit<SepaVirtualPayeeActivationState> {
  final WatchSepaVirtualPayeeActivationUsecase
  _watchSepaVirtualPayeeActivationUsecase;
  final String _recipientId;
  StreamSubscription<Result<SepaVirtualPayeeStatus, RecipientsFailure>>?
  _subscription;

  SepaVirtualPayeeActivationCubit({
    required this._watchSepaVirtualPayeeActivationUsecase,
    required this._recipientId,
  }) : super(const SepaVirtualPayeeActivationState());

  void start() {
    if (isClosed || _subscription != null || state.isActive) return;
    emit(state.copyWith(isWatching: true, failure: null));
    _subscription = _watchSepaVirtualPayeeActivationUsecase
        .execute(recipientId: _recipientId)
        .listen(_onResult, onDone: _onDone);
  }

  Future<void> retry() async {
    await _subscription?.cancel();
    _subscription = null;
    start();
  }

  void _onResult(Result<SepaVirtualPayeeStatus, RecipientsFailure> result) {
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(status: value, failure: null));
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
    }
  }

  void _onDone() {
    _subscription = null;
    if (isClosed) return;
    emit(state.copyWith(isWatching: false));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    return super.close();
  }
}
