import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction.freezed.dart';

@freezed
sealed class Transaction with _$Transaction {
  const factory Transaction({
    WalletTransaction? walletTransaction,
    Swap? swap,
    Payjoin? payjoin,
    Order? order,
  }) = _Transaction;
  const Transaction._();

  String? get txId =>
      walletTransaction?.txId ??
      swap?.txId ??
      payjoin?.txId ??
      order?.transactionId;
  bool get isTestnet =>
      walletTransaction?.isTestnet ??
      swap?.environment.isTestnet ??
      payjoin?.isTestnet ??
      order?.isTestnet ??
      false;
  bool get isBitcoin =>
      walletTransaction?.isBitcoin ??
      swap?.isBitcoin ??
      payjoin?.isBitcoin ??
      order?.isBitcoin ??
      false;
  bool get isLiquid =>
      walletTransaction?.isLiquid ??
      swap?.isLiquid ??
      payjoin?.isLiquid ??
      order?.isLiquid ??
      false;
  String? get toAddress => walletTransaction?.toAddress ?? order?.toAddress;

  bool get isBroadcasted => walletTransaction != null;
  bool get isSwap => swap != null;
  bool get isOngoingSwap => isSwap && swap?.status != SwapStatus.completed;
  bool get isPayjoin => payjoin != null;
  bool get isOngoingPayjoin => isPayjoin && !isBroadcasted;
  bool get isOngoingPayjoinReceiver =>
      isOngoingPayjoin && payjoin is PayjoinReceiver;
  bool get isOngoingPayjoinSender =>
      isOngoingPayjoin && payjoin is PayjoinSender;
  bool get isOrder => order != null;
  bool get isBuyOrder => isOrder && order!.orderType == OrderType.buy;
  bool get isSellOrder => isOrder && order!.orderType == OrderType.sell;
  bool get isOutgoing =>
      walletTransaction != null
          ? walletTransaction!.isOutgoing
          : swap?.isLnSendSwap == true ||
              swap?.isChainSwap == true ||
              payjoin is PayjoinSender;
  bool get isIncoming =>
      walletTransaction?.isIncoming ??
      swap?.isLnReceiveSwap == true ||
          swap?.isChainSwap == true ||
          payjoin is PayjoinReceiver ||
          order?.isIncoming == true;

  bool get isLnSwap => isSwap && (swap!.isLnReceiveSwap || swap!.isLnSendSwap);
  bool get isChainSwap => isSwap && swap!.isChainSwap;

  DateTime? get timestamp =>
      swap?.creationTime ??
      payjoin?.createdAt ??
      order?.createdAt ??
      walletTransaction?.confirmationTime;

  int get amountSat =>
      walletTransaction?.amountSat ??
      (swap != null
          ? swap!.amountSat - (swap!.fees?.totalFees(swap!.amountSat) ?? 0)
          : payjoin?.amountSat ?? 0);

  String get walletId =>
      walletTransaction?.walletId ?? swap?.walletId ?? payjoin!.walletId;

  List<String>? get labels => walletTransaction?.labels;
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
