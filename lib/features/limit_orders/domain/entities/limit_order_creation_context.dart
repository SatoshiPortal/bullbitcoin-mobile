import 'package:exchange/exchange.dart';

enum LimitOrderWalletType { bitcoin, lightning, liquid }

final class LimitOrderWallet {
  final LimitOrderWalletType type;
  final String address;

  LimitOrderWallet({required this.type, required this.address}) {
    if (address.isEmpty) throw ArgumentError.value(address, 'address');
  }
}

final class LimitOrderAppWallet {
  final String id;
  final String? label;
  final bool isLiquid;

  const LimitOrderAppWallet({
    required this.id,
    required this.isLiquid,
    this.label,
  });
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
  final List<LimitOrderAppWallet> appWallets;

  const LimitOrderCreationContext({
    required this.balances,
    required this.selectedCurrency,
    required this.rate,
    required this.wallets,
    this.appWallets = const [],
  });
}
