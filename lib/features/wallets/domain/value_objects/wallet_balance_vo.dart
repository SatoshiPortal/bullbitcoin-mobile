import 'package:meta/meta.dart';

@immutable
sealed class WalletBalanceVo {
  const WalletBalanceVo();

  int get totalSat;
  int get spendableSat;
}

@immutable
class BitcoinWalletBalanceVo extends WalletBalanceVo {
  /// Balance from all coinbase outputs not yet matured
  final int _immatureSat;

  /// Unconfirmed balance send out by this wallet
  final int _trustedPendingSat;

  /// Unconfirmed balance received from an external wallet
  final int _untrustedPendingSat;

  /// Confirmed and immediately spendable balance
  final int _confirmedSat;

  const BitcoinWalletBalanceVo({
    required int immatureSat,
    required int trustedPendingSat,
    required int untrustedPendingSat,
    required int confirmedSat,
  }) : _immatureSat = immatureSat,
       _trustedPendingSat = trustedPendingSat,
       _untrustedPendingSat = untrustedPendingSat,
       _confirmedSat = confirmedSat,
       super();

  int get immatureSat => _immatureSat;
  int get trustedPendingSat => _trustedPendingSat;
  int get untrustedPendingSat => _untrustedPendingSat;
  int get confirmedSat => _confirmedSat;

  @override
  int get spendableSat => _confirmedSat + _trustedPendingSat;

  @override
  int get totalSat =>
      _confirmedSat + _trustedPendingSat + _untrustedPendingSat + _immatureSat;
}

@immutable
class LiquidWalletBalanceVo extends WalletBalanceVo {
  final int _confirmedSat;

  const LiquidWalletBalanceVo({required int confirmedSat})
    : _confirmedSat = confirmedSat,
      super();

  @override
  int get spendableSat => _confirmedSat;
  @override
  int get totalSat => _confirmedSat;
}

// TODO: Implement properly with all different Arkade balances when Arkade
// needs to come out of dev mode
@immutable
class ArkadeWalletBalanceVo extends WalletBalanceVo {
  const ArkadeWalletBalanceVo() : super();

  @override
  int get spendableSat => 0;
  @override
  int get totalSat => 0;
}
