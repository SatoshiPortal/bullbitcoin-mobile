import 'package:bb_mobile/core/labels/domain/labelable.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_input.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_output.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_transaction.freezed.dart';

enum WalletTransactionDirection {
  incoming,
  outgoing,
}

enum WalletTransactionStatus {
  pending,
  confirmed,
}

@freezed
sealed class WalletTransaction with _$WalletTransaction implements Labelable {
  const factory WalletTransaction.bitcoin({
    required String walletId,
    required WalletTransactionDirection direction,
    required WalletTransactionStatus status,
    required String txId,
    required int amountSat,
    required int feeSat,
    required List<TransactionInput> inputs,
    required List<TransactionOutput> outputs,
    DateTime? confirmationTime,
    @Default(false) bool isToSelf,
    @Default([]) List<String> labels,
    @Default('') String payjoinId,
    @Default('') String swapId,
    @Default('') String exchangeId,
  }) = BitcoinWalletTransaction;
  const factory WalletTransaction.liquid({
    required String walletId,
    required WalletTransactionDirection direction,
    required WalletTransactionStatus status,
    required String txId,
    required int amountSat,
    required int feeSat,
    required List<TransactionInput> inputs,
    required List<TransactionOutput> outputs,
    DateTime? confirmationTime,
    @Default(false) bool isToSelf,
    @Default([]) List<String> labels,
    @Default('') String swapId,
    @Default('') String exchangeId,
  }) = LiquidWalletTransaction;
  const WalletTransaction._();

  bool get isIncoming => direction == WalletTransactionDirection.incoming;
  bool get isOutgoing => direction == WalletTransactionDirection.outgoing;
  bool get isPending => status == WalletTransactionStatus.pending;
  bool get isConfirmed => status == WalletTransactionStatus.confirmed;
  bool get isPayjoin =>
      this is BitcoinWalletTransaction &&
      (this as BitcoinWalletTransaction).payjoinId.isNotEmpty;
  bool get isSwap => swapId.isNotEmpty;
  bool get isExchange => exchangeId.isNotEmpty;

  @override
  String get labelRef => txId;
}

// This is the final type that is translated from a WalletTransaction
// It knows the specific details of the transaction like if its a swap, payjoin etc.
@freezed
sealed class Transaction with _$Transaction {
  const Transaction._();
  factory Transaction.onchain({
    required String walletId,
    required WalletTransactionDirection direction,
    required String txId,
    required int amountSat,
    required int fees,
    DateTime? confirmationTime,
    required Network network,
    List<String>? labels,
  }) = OnchainTransaction;
  factory Transaction.lnSwap({
    required String walletId,
    required WalletTransactionDirection direction,
    required int amountSat,
    DateTime? confirmationTime,
    required Network network,
    required Swap swap,
    List<String>? labels,
  }) = LnSwapTransaction;
  factory Transaction.chainSwap({
    required String walletId,
    required WalletTransactionDirection direction,
    required int amountSat,
    DateTime? confirmationTime,
    required Network network,
    required Swap swap,
    List<String>? labels,
  }) = ChainSwapTransaction;
  factory Transaction.self({
    required String walletId,
    required WalletTransactionDirection direction,
    required String txId,
    required int amountSat,
    required int fees,
    DateTime? confirmationTime,
    required Network network,
    List<String>? labels,
  }) = SelfTransactionDetail;

  TxType get type {
    return map(
      onchain: (_) => TxType.onchain,
      self: (_) => TxType.self,
      lnSwap: (_) => TxType.lnSwap,
      chainSwap: (_) => TxType.chainSwap,
    );
  }
}

extension OnchainTransactionFactory on OnchainTransaction {
  static OnchainTransaction fromWalletTx(
    WalletTransaction tx,
    Network network,
  ) {
    return OnchainTransaction(
      walletId: tx.walletId,
      direction: tx.direction,
      txId: tx.txId,
      amountSat: tx.amountSat,
      fees: tx.feeSat,
      confirmationTime: tx.confirmationTime,
      network: network,
    );
  }
}

extension LnSwapTransactionFactory on LnSwapTransaction {
  static LnSwapTransaction fromWalletTx(
    WalletTransaction tx,
    Network network,
    Swap swap,
  ) {
    return LnSwapTransaction(
      walletId: tx.walletId,
      direction: tx.direction,
      amountSat: tx.amountSat,
      confirmationTime: tx.confirmationTime,
      network: network,
      swap: swap,
    );
  }
}

extension ChainSwapTransactionFactory on ChainSwapTransaction {
  static ChainSwapTransaction fromWalletTx(
    WalletTransaction tx,
    Network network,
    Swap swap,
  ) {
    return ChainSwapTransaction(
      walletId: tx.walletId,
      direction: tx.direction,
      amountSat: tx.amountSat,
      confirmationTime: tx.confirmationTime,
      network: network,
      swap: swap,
    );
  }
}

enum TxType {
  @JsonValue('onchain')
  onchain,
  @JsonValue('self')
  self,
  @JsonValue('ln_swap')
  lnSwap,
  @JsonValue('chain_swap')
  chainSwap,
}
