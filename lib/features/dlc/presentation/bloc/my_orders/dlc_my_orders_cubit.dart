import 'package:bb_mobile/core/dlc/domain/entities/dlc_order.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/cancel_dlc_order_usecase.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/get_my_orders_usecase.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/sign_and_submit_cets_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dlc_my_orders_state.dart';
part 'dlc_my_orders_cubit.freezed.dart';

class DlcMyOrdersCubit extends Cubit<DlcMyOrdersState> {
  DlcMyOrdersCubit({
    required GetMyOrdersUsecase getMyOrdersUsecase,
    required CancelDlcOrderUsecase cancelDlcOrderUsecase,
    required SignAndSubmitCetsUsecase signAndSubmitCetsUsecase,
  })  : _getMyOrdersUsecase = getMyOrdersUsecase,
        _cancelDlcOrderUsecase = cancelDlcOrderUsecase,
        _signAndSubmitCetsUsecase = signAndSubmitCetsUsecase,
        super(const DlcMyOrdersState());

  final GetMyOrdersUsecase _getMyOrdersUsecase;
  final CancelDlcOrderUsecase _cancelDlcOrderUsecase;
  final SignAndSubmitCetsUsecase _signAndSubmitCetsUsecase;

  Future<void> loadMyOrders() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final orders = await _getMyOrdersUsecase.execute();
      emit(state.copyWith(isLoading: false, orders: orders));
    } on Exception catch (e) {
      emit(state.copyWith(isLoading: false, error: e));
    }
  }

  Future<void> cancelOrder({required String orderId}) async {
    emit(state.copyWith(
      isCancelling: true,
      cancellingIds: [...state.cancellingIds, orderId],
    ));
    try {
      await _cancelDlcOrderUsecase.execute(orderId: orderId);
      final updatedOrders =
          state.orders.where((o) => o.id != orderId).toList();
      emit(state.copyWith(
        isCancelling: false,
        cancellingIds:
            state.cancellingIds.where((id) => id != orderId).toList(),
        orders: updatedOrders,
      ));
    } on Exception catch (e) {
      emit(state.copyWith(
        isCancelling: false,
        cancellingIds:
            state.cancellingIds.where((id) => id != orderId).toList(),
        error: e,
      ));
    }
  }

  /// Taker accept flow: fetch accept context → sign CETs → submit accept-match.
  /// Progress is reflected in [signingStep] and [signingOrderId].
  Future<void> signAndSubmitTaker({required String orderId}) async {
    emit(state.copyWith(
      signingOrderId: orderId,
      signingStep: null,
      error: null,
    ));
    try {
      await for (final event
          in _signAndSubmitCetsUsecase.executeTaker(orderId: orderId)) {
        if (event.isDone) {
          // Remove or update the order in the list once accepted.
          final updatedOrders =
              state.orders.where((o) => o.id != orderId).toList();
          emit(state.copyWith(
            signingOrderId: null,
            signingStep: null,
            orders: updatedOrders,
          ));
        } else {
          emit(state.copyWith(signingStep: event.step));
        }
      }
    } catch (e) {
      emit(state.copyWith(
        signingOrderId: null,
        signingStep: null,
        error: e is Exception ? e : Exception(e.toString()),
      ));
    }
  }

  Future<void> refresh() => loadMyOrders();
}
