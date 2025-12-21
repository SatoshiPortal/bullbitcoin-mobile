import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exchange_transactions_state.freezed.dart';

@freezed
sealed class ExchangeTransactionsState with _$ExchangeTransactionsState {
  const ExchangeTransactionsState._();

  const factory ExchangeTransactionsState({
    @Default(false) bool isLoading,
    @Default([]) List<Order> orders,
    String? errorMessage,
    OrderType? filterType,
    @Default(1) int currentPage,
    @Default(20) int pageSize,
    @Default(false) bool hasMorePages,
  }) = _ExchangeTransactionsState;

  bool get hasError => errorMessage != null;
  bool get hasOrders => orders.isNotEmpty;

  List<Order> get filteredOrders {
    if (filterType == null) return orders;
    return orders.where((o) => o.orderType == filterType).toList();
  }
}

