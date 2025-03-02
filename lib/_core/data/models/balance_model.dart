import 'package:bb_mobile/_core/domain/entities/balance.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'balance_model.freezed.dart';

@freezed
class BalanceModel with _$BalanceModel {
  const factory BalanceModel({
    required BigInt immatureSat,
    required BigInt trustedPendingSat,
    required BigInt untrustedPendingSat,
    required BigInt confirmedSat,
    required BigInt spendableSat,
    required BigInt totalSat,
  }) = _BalanceModel;
  const BalanceModel._();

  Balance toEntity() {
    return Balance(
      immatureSat: immatureSat,
      trustedPendingSat: trustedPendingSat,
      untrustedPendingSat: untrustedPendingSat,
      confirmedSat: confirmedSat,
      spendableSat: spendableSat,
      totalSat: totalSat,
    );
  }
}
