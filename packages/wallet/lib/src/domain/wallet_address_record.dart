import 'package:wallet/wallet.dart' show WalletAddressKeyChain;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_address_record.freezed.dart';

@freezed
sealed class WalletAddressRecord with _$WalletAddressRecord {
  factory WalletAddressRecord({
    required String walletId,
    required int index,
    required String address,
    @Default(WalletAddressKeyChain.external) WalletAddressKeyChain keyChain,
    //@Default(0) int highestPreviousBalanceSat,
    @Default(0) int balanceSat,
    @Default(0) int nrOfTransactions,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _WalletAddressRecord;

  const WalletAddressRecord._();

  bool get isUsed => nrOfTransactions > 0;
}
