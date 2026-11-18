import 'package:ark/ark.dart';
import 'package:bloc/bloc.dart';
import 'package:primitives/primitives.dart';

import '../domain/ark_failure.dart';
import '../domain/usecases/review_ark_payment_usecase.dart';
import '../domain/usecases/read_ark_usecase.dart';
import '../domain/usecases/confirm_ark_operation_usecase.dart';

sealed class ArkPaymentState {
  const ArkPaymentState();
}

final class ArkPaymentEditing extends ArkPaymentState {
  final ArkFailure? failure;
  const ArkPaymentEditing([this.failure]);
}

final class ArkPaymentQuoting extends ArkPaymentState {
  const ArkPaymentQuoting();
}

final class ArkPaymentReview extends ArkPaymentState {
  final ArkQuote quote;
  const ArkPaymentReview(this.quote);
}

final class ArkPaymentSubmitting extends ArkPaymentState {
  final String operationId;
  const ArkPaymentSubmitting(this.operationId);
}

final class ArkPaymentSubmitted extends ArkPaymentState {
  final ArkOperation operation;
  const ArkPaymentSubmitted(this.operation);
}

final class ArkPaymentUncertain extends ArkPaymentState {
  final String operationId;
  const ArkPaymentUncertain(this.operationId);
}

final class ArkPaymentCubit extends Cubit<ArkPaymentState> {
  final ArkAccountId account;
  final ReviewArkPaymentUsecase _review;
  final ConfirmArkOperationUsecase _confirm;
  final String Function() _operationId;
  final SynchronizeArkUsecase? synchronize;
  bool _reconciling = false;
  int _epoch = 0;
  ArkPaymentCubit(
    this._review,
    this._confirm,
    this._operationId, {
    required this.account,
    this.synchronize,
  }) : super(const ArkPaymentEditing());

  void edit() {
    if (state is ArkPaymentSubmitting ||
        state is ArkPaymentSubmitted ||
        state is ArkPaymentUncertain ||
        isClosed) {
      return;
    }
    _epoch++;
    emit(const ArkPaymentEditing());
  }

  Future<void> review({
    required String destination,
    required String amount,
  }) async {
    if (state is! ArkPaymentEditing || isClosed) return;
    final epoch = ++_epoch;
    emit(const ArkPaymentQuoting());
    final result = await _review.execute(
      account,
      destination: destination,
      amount: amount,
    );
    if (isClosed || epoch != _epoch) return;
    switch (result) {
      case Ok(:final value):
        emit(ArkPaymentReview(value));
      case Err(:final failure):
        emit(ArkPaymentEditing(failure));
    }
  }

  Future<void> confirm() async {
    final current = state;
    if (current is! ArkPaymentReview || isClosed) return;
    final id = _operationId();
    emit(ArkPaymentSubmitting(id));
    final result = await _confirm.execute(account, current.quote, id);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(ArkPaymentSubmitted(value));
      case Err(failure: ArkSubmissionUncertainFailure(:final operationId)):
        emit(ArkPaymentUncertain(operationId));
      case Err(:final failure):
        emit(ArkPaymentEditing(failure));
    }
  }

  bool get canReconcile => synchronize != null;

  Future<void> reconcile() async {
    final current = state;
    final id = switch (current) {
      ArkPaymentSubmitted(:final operation) => operation.id,
      ArkPaymentUncertain(:final operationId) => operationId,
      _ => null,
    };
    final synchronize = this.synchronize;
    if (id == null || synchronize == null || _reconciling || isClosed) return;
    _reconciling = true;
    try {
      final result = await synchronize.execute(account, renew: false);
      if (isClosed || !identical(state, current)) return;
      if (result case Ok(:final value)) {
        final matches = value.snapshot.operations.where(
          (operation) =>
              operation.id == id && operation.kind == ArkOperationKind.payment,
        );
        if (matches.length == 1) emit(ArkPaymentSubmitted(matches.single));
      }
    } finally {
      _reconciling = false;
    }
  }
}
