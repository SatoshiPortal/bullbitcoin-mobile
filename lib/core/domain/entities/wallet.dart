// TODO: an entity class that combines wallet data from fetched from a the wallet repository and wallet metadata from the wallet metadata repository
import 'package:bb_mobile/core/domain/entities/wallet_metadata.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet.freezed.dart';

@freezed
class Wallet with _$Wallet {
  const factory Wallet({
    required String id,
    required String name,
    required Network network,
    required BigInt balanceSat,
  }) = _Wallet;
}
