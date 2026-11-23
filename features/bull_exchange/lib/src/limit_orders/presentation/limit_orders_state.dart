import 'package:exchange/exchange.dart';

final class LimitOrdersState {
  final List<LimitOrder> orders;
  final bool canCreate;
  final bool isLoading;
  final bool isCancellingAll;
  final ExchangeFailure? failure;

  const LimitOrdersState({
    this.orders = const [],
    this.canCreate = true,
    this.isLoading = false,
    this.isCancellingAll = false,
    this.failure,
  });

  LimitOrdersState copyWith({
    List<LimitOrder>? orders,
    bool? canCreate,
    bool? isLoading,
    bool? isCancellingAll,
    ExchangeFailure? failure,
    bool clearFailure = false,
  }) => LimitOrdersState(
    orders: orders ?? this.orders,
    canCreate: canCreate ?? this.canCreate,
    isLoading: isLoading ?? this.isLoading,
    isCancellingAll: isCancellingAll ?? this.isCancellingAll,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}
