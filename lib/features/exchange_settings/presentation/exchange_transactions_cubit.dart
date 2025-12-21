import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/list_all_orders_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/exchange_transactions_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ExchangeTransactionsCubit extends Cubit<ExchangeTransactionsState> {
  final ListAllOrdersUsecase _listAllOrdersUsecase;

  ExchangeTransactionsCubit({
    required ListAllOrdersUsecase listAllOrdersUsecase,
  })  : _listAllOrdersUsecase = listAllOrdersUsecase,
        super(const ExchangeTransactionsState());

  Future<void> loadOrders() async {
    if (state.isLoading) return;

    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      final orders = await _listAllOrdersUsecase.execute();
      emit(state.copyWith(
        isLoading: false,
        orders: orders,
        hasMorePages: orders.length >= state.pageSize,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
    }
  }

  void setFilterType(OrderType? type) {
    emit(state.copyWith(filterType: type));
  }

  Future<void> refresh() async {
    emit(state.copyWith(
      currentPage: 1,
      errorMessage: null,
    ));
    await loadOrders();
  }

  Future<void> loadNextPage() async {
    if (state.isLoading || !state.hasMorePages) return;

    emit(state.copyWith(
      isLoading: true,
      currentPage: state.currentPage + 1,
    ));

    try {
      final newOrders = await _listAllOrdersUsecase.execute(
        limit: state.pageSize,
        offset: state.orders.length,
      );
      emit(state.copyWith(
        isLoading: false,
        orders: [...state.orders, ...newOrders],
        hasMorePages: newOrders.length >= state.pageSize,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        currentPage: state.currentPage - 1,
        errorMessage: e.toString(),
      ));
    }
  }
}






