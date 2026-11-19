import 'package:ark/ark.dart';
import 'package:bloc/bloc.dart';
import 'package:primitives/primitives.dart';

import '../domain/ark_failure.dart';
import '../domain/usecases/request_ark_receive_usecase.dart';

sealed class ArkReceiveState {
  const ArkReceiveState();
}

final class ArkReceiveEditing extends ArkReceiveState {
  final ArkFailure? failure;
  const ArkReceiveEditing([this.failure]);
}

final class ArkReceiveLoading extends ArkReceiveState {
  const ArkReceiveLoading();
}

final class ArkReceiveReady extends ArkReceiveState {
  final ArkReceiveDestination destination;
  const ArkReceiveReady(this.destination);
}

final class ArkReceiveCubit extends Cubit<ArkReceiveState> {
  final ArkAccountId account;
  final RequestArkReceiveUsecase _request;
  int _epoch = 0;
  bool _requesting = false;
  ArkReceiveCubit(this._request, {required this.account})
    : super(const ArkReceiveEditing());
  void edit() {
    if (isClosed) return;
    _epoch++;
    if (!_requesting) emit(const ArkReceiveEditing());
  }

  Future<void> request({
    required bool lightning,
    required String amount,
  }) async {
    if (_requesting || isClosed) return;
    _requesting = true;
    final epoch = ++_epoch;
    emit(const ArkReceiveLoading());
    final result = await _request.execute(
      account,
      lightning: lightning,
      amount: amount,
    );
    _requesting = false;
    if (isClosed) return;
    if (epoch != _epoch) {
      emit(const ArkReceiveEditing());
      return;
    }
    switch (result) {
      case Ok(:final value):
        emit(ArkReceiveReady(value));
      case Err(:final failure):
        emit(ArkReceiveEditing(failure));
    }
  }
}
