import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_metadata.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_transaction.freezed.dart';
part 'wallet_transaction.g.dart';

@freezed
class BaseWalletTransaction with _$BaseWalletTransaction {
  const factory BaseWalletTransaction({
    required String txid,
    required TxType type,
    required int amount,
    int? fees,
    DateTime? confirmationTime,
  }) = _BaseWalletTransaction;
  const BaseWalletTransaction._();

  factory BaseWalletTransaction.fromJson(Map<String, dynamic> json) =>
      _$BaseWalletTransactionFromJson(json);
}

@freezed
sealed class WalletTransaction with _$WalletTransaction {
  const WalletTransaction._();
  factory WalletTransaction.send({
    required String walletId,
    required String txId,
    required int amount,
    required int fees,
    DateTime? confirmationTime,
    required Network network,
  }) = SendTransactionDetail;
  factory WalletTransaction.receive({
    required String walletId,
    required String txId,
    required int amount,
    DateTime? confirmationTime,
    int? fees,
    required Network network,
  }) = ReceiveTransactionDetail;
  factory WalletTransaction.lnSwap({
    required String walletId,
    required String txId,
    required int amount,
    DateTime? confirmationTime,
    required Network network,
    required Swap swap,
  }) = LnSwapTransactionDetail;
  factory WalletTransaction.chainSwap({
    required String walletId,
    required int amount,
    DateTime? confirmationTime,
    required Network network,
    required Swap swap,
  }) = ChainSwapTransactionDetail;
  factory WalletTransaction.self({
    required String walletId,
    required String txId,
    required int amount,
    required int fees,
    DateTime? confirmationTime,
    required Network network,
  }) = SelfTransactionDetail;

  TxType get type {
    return map(
      send: (_) => TxType.send,
      receive: (_) => TxType.receive,
      self: (_) => TxType.self,
      lnSwap: (_) => TxType.lnSwap,
      chainSwap: (_) => TxType.chainSwap,
    );
  }
}

enum TxType {
  @JsonValue('send')
  send,
  @JsonValue('receive')
  receive,
  @JsonValue('self')
  self,
  @JsonValue('ln_swap')
  lnSwap,
  @JsonValue('chain_swap')
  chainSwap,
}
