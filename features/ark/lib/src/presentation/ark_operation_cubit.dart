import 'package:ark/ark.dart';
import 'package:bloc/bloc.dart';
import 'package:primitives/primitives.dart';

import '../domain/ark_failure.dart';
import '../domain/usecases/quote_ark_operation_usecase.dart';
import '../domain/usecases/confirm_ark_operation_usecase.dart';

sealed class ArkOperationState {
  const ArkOperationState();
}

final class ArkOperationLoading extends ArkOperationState {
  const ArkOperationLoading();
}

final class ArkOperationReview extends ArkOperationState {
  final ArkQuote quote;
  const ArkOperationReview(this.quote);
}

final class ArkOperationFailed extends ArkOperationState {
  final ArkFailure failure;
  const ArkOperationFailed(this.failure);
}

final class ArkOperationSubmitting extends ArkOperationState {
  const ArkOperationSubmitting();
}

final class ArkOperationSubmitted extends ArkOperationState {
  final ArkOperation operation;
  const ArkOperationSubmitted(this.operation);
}

final class ArkOperationUncertain extends ArkOperationState {
  final String operationId;
  const ArkOperationUncertain(this.operationId);
}

final class ArkOperationCubit extends Cubit<ArkOperationState> {
  final ArkAccountId account;
  final ArkQuoteRequest request;
  final QuoteArkOperationUsecase _quote;
  final ConfirmArkOperationUsecase _confirm;
  final String Function() _operationId;
  bool _loading = false;
  ArkOperationCubit(
    this._quote,
    this._confirm,
    this._operationId, {
    required this.account,
    required this.request,
  }) : super(const ArkOperationLoading());
  Future<void> load() async {
    if (isClosed ||
        _loading ||
        state is ArkOperationSubmitting ||
        state is ArkOperationSubmitted ||
        state is ArkOperationUncertain) {
      return;
    }
    _loading = true;
    emit(const ArkOperationLoading());
    final result = await _quote.execute(account, request);
    _loading = false;
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(ArkOperationReview(value));
      case Err(:final failure):
        emit(ArkOperationFailed(failure));
    }
  }

  Future<void> confirm() async {
    final current = state;
    if (current is! ArkOperationReview || isClosed) return;
    emit(const ArkOperationSubmitting());
    final id = _operationId();
    final result = await _confirm.execute(account, current.quote, id);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(ArkOperationSubmitted(value));
      case Err(failure: ArkSubmissionUncertainFailure(:final operationId)):
        emit(ArkOperationUncertain(operationId));
      case Err(:final failure):
        emit(ArkOperationFailed(failure));
    }
  }
}
