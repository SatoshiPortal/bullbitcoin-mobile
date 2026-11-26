import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_ark/bull_ark.dart';

import '../domain/entities/internal_transfer.dart';

import 'package:swaps/order_swaps.dart';

import '../domain/usecases/load_internal_ark_transfer_usecase.dart';
import '../domain/usecases/review_internal_ark_transfer_usecase.dart';

sealed class InternalArkTransferState {
  const InternalArkTransferState();
  bool get busy => false;
  ArkTransferContext? get context => null;
  SwapFailure? get failure => null;
  InternalArkTransferHandoff? get handoff => null;
}

final class InternalArkTransferLoading extends InternalArkTransferState {
  const InternalArkTransferLoading();
  @override
  bool get busy => true;
}

final class InternalArkTransferReady extends InternalArkTransferState {
  @override
  final ArkTransferContext context;
  const InternalArkTransferReady(this.context);
}

final class InternalArkTransferReviewing extends InternalArkTransferState {
  @override
  final ArkTransferContext context;
  const InternalArkTransferReviewing(this.context);
  @override
  bool get busy => true;
}

final class InternalArkTransferFailed extends InternalArkTransferState {
  @override
  final ArkTransferContext? context;
  @override
  final SwapFailure failure;
  const InternalArkTransferFailed(this.failure, {this.context});
}

final class InternalArkTransferHandingOff extends InternalArkTransferState {
  @override
  final ArkTransferContext context;
  @override
  final InternalArkTransferHandoff handoff;
  const InternalArkTransferHandingOff(this.context, this.handoff);
}

final class InternalArkTransferCubit extends Cubit<InternalArkTransferState> {
  final LoadInternalArkTransferUsecase _load;
  final ReviewInternalArkTransferUsecase _review;
  InternalArkTransferCubit(this._load, this._review)
    : super(const InternalArkTransferLoading());

  Future<void> load() async {
    final result = await _load.execute();
    if (isClosed) return;
    emit(switch (result) {
      Ok(:final value) => InternalArkTransferReady(value),
      Err(:final failure) => InternalArkTransferFailed(failure),
    });
  }

  Future<void> review(InternalTransfer transfer) async {
    final context = state.context;
    if (state.busy || state.handoff != null || isClosed || context == null) {
      return;
    }
    emit(InternalArkTransferReviewing(context));
    final result = await _review.execute(transfer);
    if (isClosed) return;
    emit(switch (result) {
      Ok(:final value) => InternalArkTransferHandingOff(context, value),
      Err(:final failure) => InternalArkTransferFailed(
        failure,
        context: context,
      ),
    });
  }

  void edit() {
    if (!isClosed &&
        !state.busy &&
        state.handoff == null &&
        state.failure != null) {
      final context = state.context;
      if (context != null) emit(InternalArkTransferReady(context));
    }
  }

  void returned() {
    final context = state.context;
    if (!isClosed && context != null) emit(InternalArkTransferReady(context));
  }
}
