import 'package:bb_mobile/core/dlc/domain/entities/dlc_order.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/cancel_dlc_order_usecase.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/get_my_orders_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dlc_my_orders_state.dart';
part 'dlc_my_orders_cubit.freezed.dart';

class DlcMyOrdersCubit extends Cubit<DlcMyOrdersState> {
  DlcMyOrdersCubit({
    required GetMyOrdersUsecase getMyOrdersUsecase,
    required CancelDlcOrderUsecase cancelDlcOrderUsecase,
  })  : _getMyOrdersUsecase = getMyOrdersUsecase,
        _cancelDlcOrderUsecase = cancelDlcOrderUsecase,
        super(const DlcMyOrdersState());

  final GetMyOrdersUsecase _getMyOrdersUsecase;
  final CancelDlcOrderUsecase _cancelDlcOrderUsecase;

  Future<void> loadMyOrders({required String pubkey}) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final orders = await _getMyOrdersUsecase.execute(pubkey: pubkey);
      emit(state.copyWith(isLoading: false, orders: orders));
    } on Exception catch (e) {
      emit(state.copyWith(isLoading: false, error: e));
    }
  }

  Future<void> cancelOrder({
    required String orderId,
    required String makerPubkey,
    /// TODO: derive signature from the wallet key in a dedicated use case
    required String signatureHex,
  }) async {
    emit(
      state.copyWith(
        isCancelling: true,
        cancellingIds: [...state.cancellingIds, orderId],
      ),
    );
    try {
      await _cancelDlcOrderUsecase.execute(
        orderId: orderId,
        makerPubkey: makerPubkey,
        signatureHex: signatureHex,
      );
      final updatedOrders = state.orders.where((o) => o.id != orderId).toList();
      emit(
        state.copyWith(
          isCancelling: false,
          cancellingIds: state.cancellingIds.where((id) => id != orderId).toList(),
          orders: updatedOrders,
        ),
      );
    } on Exception catch (e) {
      emit(
        state.copyWith(
          isCancelling: false,
          cancellingIds: state.cancellingIds.where((id) => id != orderId).toList(),
          error: e,
        ),
      );
    }
  }

  Future<void> refresh({required String pubkey}) => loadMyOrders(pubkey: pubkey);
}
