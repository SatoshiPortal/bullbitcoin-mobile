import 'package:exchange/exchange.dart';
import 'package:secrets/secrets.dart';

final class LimitOrderWallet {
  final BtcNetwork type;
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
  final List<WalletRegistration> appWallets;

  const LimitOrderCreationContext({
    required this.balances,
    required this.selectedCurrency,
    required this.rate,
    required this.wallets,
    this.appWallets = const [],
  });
}
