import 'package:sync/sync.dart' show Keychain;
import 'package:labels/labels.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_address.freezed.dart';

@freezed
sealed class WalletAddress with _$WalletAddress {
  factory WalletAddress({
    required String walletId,
    required int index,
    required String address,
    @Default(Keychain.external) Keychain keyChain,
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
