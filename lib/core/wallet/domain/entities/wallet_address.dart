import 'package:bb_mobile/features/labels/labels.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_address.freezed.dart';

enum WalletAddressKeyChain { internal, external }

@freezed
sealed class WalletAddress with _$WalletAddress {
  factory WalletAddress({
    required String walletId,
    required int index,
    required String address,
    @Default(WalletAddressKeyChain.external) WalletAddressKeyChain keyChain,
    //@Default(0) int highestPreviousBalanceSat,
    @Default(0) int balanceSat,
    @Default(0) int nrOfTransactions,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default([]) List<Label> labels,
  }) = _WalletAddress;

  const WalletAddress._();

  bool get isUsed => nrOfTransactions > 0;
}
