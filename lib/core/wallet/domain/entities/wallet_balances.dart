import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_balances.freezed.dart';

@freezed
abstract class WalletBalances with _$WalletBalances {
  const factory WalletBalances({
    required int immatureSat,
    required int trustedPendingSat,
    required int untrustedPendingSat,
    required int confirmedSat,
    required int spendableSat,
    required int totalSat,
  }) = _WalletBalances;
}
