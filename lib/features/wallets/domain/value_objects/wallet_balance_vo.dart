import 'package:meta/meta.dart';

import '../errors/wallet_errors.dart';

@immutable
sealed class WalletBalanceVO {
  const WalletBalanceVO();

  int get totalSat;
  int get spendableSat;
}

@immutable
class BitcoinWalletBalanceVO extends WalletBalanceVO {
  /// Balance from all coinbase outputs not yet matured
  final int _immatureSat;

  /// Unconfirmed balance send out by this wallet
  final int _trustedPendingSat;

  /// Unconfirmed balance received from an external wallet
  final int _untrustedPendingSat;

  /// Confirmed and immediately spendable balance
  final int _confirmedSat;

  const BitcoinWalletBalanceVO({
    required int immatureSat,
    required int trustedPendingSat,
    required int untrustedPendingSat,
    required int confirmedSat,
  }) : _immatureSat = immatureSat,
       _trustedPendingSat = trustedPendingSat,
       _untrustedPendingSat = untrustedPendingSat,
       _confirmedSat = confirmedSat,
       super() {
    if (immatureSat < 0) {
      throw InvalidBalanceError(field: 'immatureSat', value: immatureSat);
    }
    if (trustedPendingSat < 0) {
      throw InvalidBalanceError(field: 'trustedPendingSat', value: trustedPendingSat);
    }
    if (untrustedPendingSat < 0) {
      throw InvalidBalanceError(field: 'untrustedPendingSat', value: untrustedPendingSat);
    }
    if (confirmedSat < 0) {
      throw InvalidBalanceError(field: 'confirmedSat', value: confirmedSat);
    }
  }

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
class LiquidWalletBalanceVO extends WalletBalanceVO {
  final int _confirmedSat;

  const LiquidWalletBalanceVO({required int confirmedSat})
    : _confirmedSat = confirmedSat,
      super() {
    if (confirmedSat < 0) {
      throw InvalidBalanceError(field: 'confirmedSat', value: confirmedSat);
    }
  }

  @override
  int get spendableSat => _confirmedSat;
  @override
  int get totalSat => _confirmedSat;
}

// TODO: Implement properly with all different Arkade balances when Arkade
// needs to come out of dev mode
@immutable
class ArkadeWalletBalanceVO extends WalletBalanceVO {
  const ArkadeWalletBalanceVO() : super();

  @override
  int get spendableSat => 0;
  @override
  int get totalSat => 0;
}
