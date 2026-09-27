import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_creation_context.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_rate.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';

enum CreateLimitOrderStep { intro, target, amount, wallet, confirmation, done }

final class CreateLimitOrderState {
  final CreateLimitOrderStep step;
  final bool isLoading;
  final bool isSubmitting;
  final List<LimitOrderBalance> balances;
  final FiatCurrency? currency;
  final LimitOrderRate? rate;
  final double discount;
  final double limitPrice;
  final double fiatAmount;
  final List<LimitOrderWallet> wallets;
  final LimitOrderWallet? wallet;
  final LimitOrder? createdOrder;
  final LimitOrdersFailure? failure;

  const CreateLimitOrderState({
    this.step = CreateLimitOrderStep.intro,
    this.isLoading = false,
    this.isSubmitting = false,
    this.balances = const [],
    this.currency,
    this.rate,
    this.discount = 1,
    this.limitPrice = 0,
    this.fiatAmount = 0,
    this.wallets = const [],
    this.wallet,
    this.createdOrder,
    this.failure,
  });

  LimitOrderBalance? get selectedBalance => currency == null
      ? null
      : balances.where((balance) => balance.currency == currency).firstOrNull;

  double get estimatedBtcAmount =>
      limitPrice <= 0 ? 0 : fiatAmount / limitPrice;

  double get estimatedBuyPrice => rate?.estimatedBuyPrice(limitPrice) ?? 0;

  CreateLimitOrderState copyWith({
    CreateLimitOrderStep? step,
    bool? isLoading,
    bool? isSubmitting,
    List<LimitOrderBalance>? balances,
    FiatCurrency? currency,
    LimitOrderRate? rate,
    double? discount,
    double? limitPrice,
    double? fiatAmount,
    List<LimitOrderWallet>? wallets,
    LimitOrderWallet? wallet,
    bool clearWallet = false,
    LimitOrder? createdOrder,
    LimitOrdersFailure? failure,
    bool clearFailure = false,
  }) => CreateLimitOrderState(
    step: step ?? this.step,
    isLoading: isLoading ?? this.isLoading,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    balances: balances ?? this.balances,
    currency: currency ?? this.currency,
    rate: rate ?? this.rate,
    discount: discount ?? this.discount,
    limitPrice: limitPrice ?? this.limitPrice,
    fiatAmount: fiatAmount ?? this.fiatAmount,
    wallets: wallets ?? this.wallets,
    wallet: clearWallet ? null : wallet ?? this.wallet,
    createdOrder: createdOrder ?? this.createdOrder,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}
