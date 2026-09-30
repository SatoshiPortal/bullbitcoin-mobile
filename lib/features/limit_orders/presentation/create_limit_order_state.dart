import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_amount_limits.dart';
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
  final List<Wallet> appWallets;
  final LimitOrderWallet? wallet;
  final String? selectedAppWalletId;
  final bool isResolvingAddress;
  final String lightningAddressInput;
  final bool lightningAddressInvalid;
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
    this.appWallets = const [],
    this.wallet,
    this.selectedAppWalletId,
    this.isResolvingAddress = false,
    this.lightningAddressInput = '',
    this.lightningAddressInvalid = false,
    this.createdOrder,
    this.failure,
  });

  LimitOrderBalance? get selectedBalance => currency == null
      ? null
      : balances.where((balance) => balance.currency == currency).firstOrNull;

  double get estimatedBtcAmount =>
      limitPrice <= 0 ? 0 : fiatAmount / limitPrice;

  double get estimatedBuyPrice => rate?.estimatedBuyPrice(limitPrice) ?? 0;

  /// The buy-limit violation for the chosen destination network, or null when
  /// the amount is within limits (or no destination/rate is set yet).
  LimitOrderAmountViolation? get amountLimitViolation {
    final currentRate = rate;
    final destination = wallet;
    if (currentRate == null || destination == null) return null;
    return LimitOrderAmountLimits.check(
      fiatAmount: fiatAmount,
      userPrice: currentRate.userPrice,
      network: destination.type,
    );
  }

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
    List<Wallet>? appWallets,
    LimitOrderWallet? wallet,
    bool clearWallet = false,
    String? selectedAppWalletId,
    bool clearSelectedAppWallet = false,
    bool? isResolvingAddress,
    String? lightningAddressInput,
    bool? lightningAddressInvalid,
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
    appWallets: appWallets ?? this.appWallets,
    wallet: clearWallet ? null : wallet ?? this.wallet,
    selectedAppWalletId: clearSelectedAppWallet
        ? null
        : selectedAppWalletId ?? this.selectedAppWalletId,
    isResolvingAddress: isResolvingAddress ?? this.isResolvingAddress,
    lightningAddressInput: lightningAddressInput ?? this.lightningAddressInput,
    lightningAddressInvalid:
        lightningAddressInvalid ?? this.lightningAddressInvalid,
    createdOrder: createdOrder ?? this.createdOrder,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}
