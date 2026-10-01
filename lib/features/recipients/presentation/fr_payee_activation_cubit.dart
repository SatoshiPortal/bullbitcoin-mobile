import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/entities/sepa_virtual_payee_activation_progress.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/watch_sepa_virtual_payee_activation_usecase.dart';
import 'package:bb_mobile/features/recipients/presentation/recipient_view_model_mapper.dart';
import 'package:bb_mobile/features/recipients/public/recipient_view_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'fr_payee_activation_state.dart';
part 'fr_payee_activation_cubit.freezed.dart';

class FrPayeeActivationCubit extends Cubit<FrPayeeActivationState> {
  final WatchSepaVirtualPayeeActivationUsecase _watchActivationUsecase;
  StreamSubscription<
    Result<SepaVirtualPayeeActivationProgress, RecipientsFailure>
  >?
  _subscription;

  FrPayeeActivationCubit(
    this._watchActivationUsecase, {
    required RecipientViewModel recipient,
  }) : super(FrPayeeActivationState(recipient: recipient));

  Future<void> start() async {
    if (isClosed || _subscription != null) return;
    emit(state.copyWith(isActivating: true, failure: null));
    _subscription = _watchActivationUsecase
        .execute(recipientId: state.recipient.id)
        .listen(_onResult, onDone: () => _subscription = null);
  }

  Future<void> retry() async {
    if (isClosed) return;
    await _subscription?.cancel();
    _subscription = null;
    emit(
      state.copyWith(
        failure: null,
        isActivating: false,
        initialWaitTimedOut: false,
      ),
    );
    await start();
  }

  void _onResult(
    Result<SepaVirtualPayeeActivationProgress, RecipientsFailure> result,
  ) {
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        final recipient = value.recipient.toViewModel();
        emit(
          state.copyWith(
            recipient: recipient,
            isActive: recipient.isVirtualPayeeActive,
            isActivating: !recipient.isVirtualPayeeActive,
            initialWaitTimedOut: value.initialWaitTimedOut,
            failure: null,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(isActivating: false, failure: failure));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
