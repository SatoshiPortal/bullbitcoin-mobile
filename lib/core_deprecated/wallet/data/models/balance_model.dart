import 'package:freezed_annotation/freezed_annotation.dart';

part 'balance_model.freezed.dart';

@freezed
sealed class BalanceModel with _$BalanceModel {
  const factory BalanceModel({
    required BigInt immatureSat,
    required BigInt trustedPendingSat,
    required BigInt untrustedPendingSat,
    required BigInt confirmedSat,
    required BigInt spendableSat,
    required BigInt totalSat,
  }) = _BalanceModel;
}
