import 'package:freezed_annotation/freezed_annotation.dart';

part 'balance.freezed.dart';

@freezed
class Balance with _$Balance {
  const factory Balance({
    required BigInt immatureSat,
    required BigInt trustedPendingSat,
    required BigInt untrustedPendingSat,
    required BigInt confirmedSat,
    required BigInt spendableSat,
    required BigInt totalSat,
  }) = _Balance;
}
