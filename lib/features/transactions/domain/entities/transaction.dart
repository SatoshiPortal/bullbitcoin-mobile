import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:drift/drift.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction.freezed.dart';

@freezed
sealed class Transaction with _$Transaction {
  // Factory constructor for a transaction that was already broadcasted and
  // picked up by the wallet.
  const factory Transaction.broadcasted({
    required WalletTransaction walletTransaction,
    Swap? swap,
    Payjoin? payjoin,
  }) = BroadcastedTransaction;
  // Factory constructor for a swap that has been created but not broadcasted or
  //  picked up by the wallet yet.
  const factory Transaction.ongoingSwap({
    required Swap swap,
    // Payjoin? payjoin, // Maybe in the future swaps can be done with payjoin
  }) = OngoingSwapTransaction;
  // Factory constructor for a payjoin that has been created but not broadcasted
  // or picked up by the wallet yet.
  const factory Transaction.ongoingPayjoin({required Payjoin payjoin}) =
      OngoingPayjoinTransaction;
  const Transaction._();

  WalletTransaction? get walletTransaction => switch (this) {
    BroadcastedTransaction(walletTransaction: final wt) => wt,
    OngoingSwapTransaction() => null,
    OngoingPayjoinTransaction() => null,
  };
  Swap? get swap => switch (this) {
    BroadcastedTransaction(swap: final swap) => swap,
    OngoingSwapTransaction(swap: final swap) => swap,
    OngoingPayjoinTransaction() => null,
  };
  Payjoin? get payjoin => switch (this) {
    BroadcastedTransaction(payjoin: final payjoin) => payjoin,
    OngoingSwapTransaction() => null,
    OngoingPayjoinTransaction(payjoin: final payjoin) => payjoin,
  };
  String? get txId => switch (this) {
    BroadcastedTransaction(walletTransaction: final wt) => wt.txId,
    OngoingSwapTransaction(swap: final swap) => swap.txId,
    OngoingPayjoinTransaction(payjoin: final payjoin) => payjoin.txId,
  };

  bool get isSwap => swap != null;
  bool get isOngoingSwap => this is OngoingSwapTransaction;
  bool get isPayjoin => payjoin != null;
  bool get isOngoingPayjoin => this is OngoingPayjoinTransaction;
  bool get isOngoingPayjoinSender =>
      isOngoingPayjoin && payjoin is PayjoinSender;

  bool get isOutgoing =>
      walletTransaction?.isOutgoing == true ||
      swap?.isLnSendSwap == true ||
      swap?.isChainSwap == true ||
      payjoin is PayjoinSender;
  bool get isIncoming =>
      walletTransaction?.isIncoming == true ||
      swap?.isLnReceiveSwap == true ||
      swap?.isChainSwap == true ||
      payjoin is PayjoinReceiver;
  bool get isBitcoin =>
      walletTransaction?.isBitcoin == true ||
      payjoin != null ||
      [
        SwapType.bitcoinToLightning,
        SwapType.bitcoinToLiquid,
        SwapType.lightningToBitcoin,
        SwapType.liquidToBitcoin,
      ].contains(swap?.type);
  bool get isLiquid =>
      walletTransaction?.isLiquid == true ||
      [
        SwapType.liquidToLightning,
        SwapType.liquidToBitcoin,
        SwapType.lightningToLiquid,
        SwapType.bitcoinToLiquid,
      ].contains(swap?.type);
  bool get isLnSwap => isSwap && (swap!.isLnReceiveSwap || swap!.isLnSendSwap);
  bool get isChainSwap => isSwap && swap!.isChainSwap;

  DateTime? get timestamp => switch (this) {
    BroadcastedTransaction(
      walletTransaction: final wt,
      swap: final swap,
      payjoin: final payjoin,
    ) =>
      swap?.creationTime ?? payjoin?.createdAt ?? wt.confirmationTime,
    OngoingSwapTransaction(swap: final swap) => swap.creationTime,
    OngoingPayjoinTransaction(payjoin: final payjoin) => payjoin.createdAt,
  };

  int get amountSat =>
      walletTransaction?.amountSat ??
      swap?.amountSat ??
      payjoin?.amountSat ??
      0;

  String get walletId =>
      walletTransaction?.walletId ?? swap?.walletId ?? payjoin!.walletId;
}

/*
  String? get txId =>
      walletTransaction?.txId ??
      payjoin?.txId ??
      payjoin?.originalTxId ??
      swap?.txId;
  int get amountSat =>
      walletTransaction?.amountSat ??
      payjoin?.amountSat ??
      swap?.amountSat ??
      0;
  DateTime? get timestamp =>
      payjoin?.createdAt ??
      swap?.creationTime ??
      walletTransaction?.confirmationTime;
  bool get isBitcoin =>
      walletTransaction != null && walletTransaction!.isBitcoin ||
      isPayjoin ||
      swap?.type == SwapType.bitcoinToLiquid;
  bool get isTestnet => fromWallet?.isTestnet ?? toWallet?.isTestnet ?? false;
  bool get isLightning => [
    SwapType.lightningToBitcoin,
    SwapType.lightningToLiquid,
    SwapType.liquidToLightning,
    SwapType.bitcoinToLightning,
  ].contains(swap?.type);
  Wallet? get wallet =>
      isIncoming
          ? toWallet
          : isOutgoing
          ? fromWallet
          : toWallet ?? fromWallet;
  bool get isIncoming => toWallet != null && fromWallet == null;
  bool get isOutgoing => fromWallet != null && toWallet == null;
  bool get isToSameWallet =>
      toWallet != null && fromWallet != null && toWallet!.id == fromWallet!.id;
  bool get isBetweenWallets =>
      toWallet != null && fromWallet != null && toWallet!.id != fromWallet!.id;

  bool get isSwap => swap != null;
  bool get isPayjoin => payjoin != null;
  */
