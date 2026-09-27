import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_rate.dart';

enum LimitOrderWalletType { bitcoin, lightning, liquid }

final class LimitOrderWallet {
  final LimitOrderWalletType type;
  final String address;

  LimitOrderWallet({required this.type, required this.address}) {
    if (address.isEmpty) throw ArgumentError.value(address, 'address');
  }
}

final class LimitOrderBalance {
  final FiatCurrency currency;
  final double amount;

  LimitOrderBalance({required this.currency, required this.amount}) {
    if (amount < 0) throw ArgumentError.value(amount, 'amount');
  }
}

final class LimitOrderCreationContext {
  final List<LimitOrderBalance> balances;
  final FiatCurrency selectedCurrency;
  final LimitOrderRate rate;
  final List<LimitOrderWallet> wallets;

  const LimitOrderCreationContext({
    required this.balances,
    required this.selectedCurrency,
    required this.rate,
    required this.wallets,
  });
}
