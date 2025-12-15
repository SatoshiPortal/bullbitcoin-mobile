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
    List<String>? labels,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _WalletAddress;

  // Todo: the following should not be defined here, the reason it is called
  //  WalletAddress and not just Address is because this is for addresses from
  //  the wallet itself, with index etc, not for external addresses. This should be removed.
  //factory WalletAddress.external({required String payload}) = AddressOnly;

  const WalletAddress._();

  bool get isUsed => nrOfTransactions > 0;
}
