import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet.freezed.dart';

@freezed
class Wallet with _$Wallet {
  const factory Wallet({
    required String id,
    required String name,
    required Network network,
    required BigInt balanceSat,
    required bool isDefault,
  }) = _Wallet;
}
