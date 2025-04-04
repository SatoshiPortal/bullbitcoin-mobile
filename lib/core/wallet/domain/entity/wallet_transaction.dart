import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_transaction.freezed.dart';
part 'wallet_transaction.g.dart';

// This is the base type that is first translated from the datasource
// It only knows if a transaction is Bitcoin/Liquid Send/Receive
@freezed
class BaseWalletTransaction with _$BaseWalletTransaction {
  const factory BaseWalletTransaction({
    required String walletId,
    required Network network,
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

// This is the final type that is translated from a BaseWalletTransaction
// It knows the specific details of the transaction like if its a swap, payjoin etc.
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
    List<String>? labels,
  }) = ReceiveTransactionDetail;
  factory WalletTransaction.lnSwap({
    required String walletId,
    required int amount,
    DateTime? confirmationTime,
    required Network network,
    required Swap swap,
    List<String>? labels,
  }) = LnSwapTransactionDetail;
  factory WalletTransaction.chainSwap({
    required String walletId,
    required int amount,
    DateTime? confirmationTime,
    required Network network,
    required Swap swap,
    List<String>? labels,
  }) = ChainSwapTransactionDetail;
  factory WalletTransaction.self({
    required String walletId,
    required String txId,
    required int amount,
    required int fees,
    DateTime? confirmationTime,
    required Network network,
    List<String>? labels,
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

extension SendTransactionFactory on SendTransactionDetail {
  static SendTransactionDetail fromBaseWalletTx(BaseWalletTransaction tx) {
    return SendTransactionDetail(
      walletId: tx.walletId,
      txId: tx.txid,
      amount: tx.amount,
      fees: tx.fees ?? 0,
      confirmationTime: tx.confirmationTime,
      network: tx.network,
    );
  }
}

extension ReceiveTransactionFactory on ReceiveTransactionDetail {
  static ReceiveTransactionDetail fromBaseWalletTx(BaseWalletTransaction tx) {
    return ReceiveTransactionDetail(
      walletId: tx.walletId,
      txId: tx.txid,
      amount: tx.amount,
      confirmationTime: tx.confirmationTime,
      fees: tx.fees,
      network: tx.network,
    );
  }
}

extension LnSwapTransactionFactory on LnSwapTransactionDetail {
  static LnSwapTransactionDetail fromBaseWalletTx(
    BaseWalletTransaction tx,
    Swap swap,
  ) {
    return LnSwapTransactionDetail(
      walletId: tx.walletId,
      amount: tx.amount,
      confirmationTime: tx.confirmationTime,
      network: tx.network,
      swap: swap,
    );
  }
}

extension ChainSwapTransactionFactory on ChainSwapTransactionDetail {
  static ChainSwapTransactionDetail fromBaseWalletTx(
    BaseWalletTransaction tx,
    Swap swap,
  ) {
    return ChainSwapTransactionDetail(
      walletId: tx.walletId,
      amount: tx.amount,
      confirmationTime: tx.confirmationTime,
      network: tx.network,
      swap: swap,
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
