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
  }) = SendTransactionDetail;
  factory WalletTransaction.receive({
    required String walletId,
    required String txId,
    required int amount,
    DateTime? confirmationTime,
    int? fees,
  }) = ReceiveTransactionDetail;
  factory WalletTransaction.lnSwap({
    required String swapId,
    required int amount,
    required int fees,
    DateTime? confirmationTime,
  }) = LnSwapTransactionDetail;
  factory WalletTransaction.chainSwap({
    required String swapId,
    required int amount,
    required int fees,
    DateTime? confirmationTime,
  }) = ChainSwapTransactionDetail;
  factory WalletTransaction.self({
    required String walletId,
    required String txId,
    required int amount,
    required int fees,
    DateTime? confirmationTime,
  }) = SelfTransactionDetail;
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
