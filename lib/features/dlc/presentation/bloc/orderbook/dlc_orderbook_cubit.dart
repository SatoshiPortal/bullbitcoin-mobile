import 'package:bb_mobile/core/dlc/domain/entities/dlc_order.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/get_orderbook_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dlc_orderbook_state.dart';
part 'dlc_orderbook_cubit.freezed.dart';

class DlcOrderbookCubit extends Cubit<DlcOrderbookState> {
  DlcOrderbookCubit({required GetOrderbookUsecase getOrderbookUsecase})
      : _getOrderbookUsecase = getOrderbookUsecase,
        super(const DlcOrderbookState());

  final GetOrderbookUsecase _getOrderbookUsecase;

  Future<void> loadOrderbook({required String instrumentId}) async {
    emit(state.copyWith(isLoading: true, error: null, selectedInstrumentId: instrumentId));
    try {
      final orders = await _getOrderbookUsecase.execute(instrumentId: instrumentId);
      emit(state.copyWith(isLoading: false, orders: orders));
    } on Exception catch (e) {
      emit(state.copyWith(isLoading: false, error: e));
    }
  }

  Future<void> refresh() async {
    final instrumentId = state.selectedInstrumentId;
    if (instrumentId == null) return;
    await loadOrderbook(instrumentId: instrumentId);
  }
}
