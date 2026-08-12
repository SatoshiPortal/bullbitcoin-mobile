import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:bull_payjoin/bull_payjoin.dart';

part 'transaction.freezed.dart';

@freezed
sealed class Transaction with _$Transaction {
  const factory Transaction({
    WalletTransaction? walletTransaction,
    Swap? swap,
    PayjoinSession? payjoin,
    OrderSwapRecord? orderSwap,
    Order? order,
  }) = _Transaction;
  const Transaction._();

  String? get txId =>
      walletTransaction?.txId ??
      swap?.txId ??
      orderSwap?.canonicalWalletTransactionId ??
      payjoin?.txId ??
      order?.transactionId;
  bool get isTestnet =>
      walletTransaction?.isTestnet ??
      swap?.environment.isTestnet ??
      (orderSwap == null
          ? null
          : orderSwap!.environment == OrderSwapEnvironment.testnet) ??
      payjoin?.isTestnet ??
      order?.isTestnet ??
      false;
  bool get isBitcoin =>
      walletTransaction?.isBitcoin ??
      swap?.isBitcoin ??
      (orderSwap == null
          ? null
          : orderSwap!.canonicalWalletNetwork == OrderSwapNetwork.bitcoin) ??
      payjoin?.isBitcoin ??
      order?.isBitcoin ??
      false;
  bool get isLiquid =>
      walletTransaction?.isLiquid ??
      swap?.isLiquid ??
      (orderSwap == null
          ? null
          : orderSwap!.canonicalWalletNetwork == OrderSwapNetwork.liquid) ??
      payjoin?.isLiquid ??
      order?.isLiquid ??
      false;
  String? get toAddress => walletTransaction?.toAddress ?? order?.toAddress;
  String? get orderSwapDestinationAddress =>
      orderSwap?.outNetwork == OrderSwapNetwork.lightning
      ? null
      : orderSwap?.destination;

  bool get isBroadcasted => walletTransaction != null;
  bool get isSwap => swap != null || orderSwap != null;
  bool get isOngoingSwap =>
      (swap != null && !swap!.status.isTerminal) ||
      (orderSwap != null && !orderSwap!.localStatus.isTerminal);
  bool get isPayjoin => payjoin != null;
  bool get isOngoingPayjoin => isPayjoin && !isBroadcasted;
  bool get isOngoingPayjoinReceiver =>
      isOngoingPayjoin && payjoin is PayjoinReceiverSession;
  bool get isOngoingPayjoinSender =>
      isOngoingPayjoin && payjoin is PayjoinSenderSession;

  /// The payjoin status to DISPLAY, derived from what actually happened
  /// on-chain rather than from the session row alone. The session's
  /// persisted status can lag reality: completion/abort detection runs on
  /// background polls in the payjoin repository, so right after a payment
  /// lands the row may still say requested/proposed while the broadcast
  /// transaction is already visible in the wallet. When the wallet
  /// transaction is present, its txid is authoritative:
  /// - it IS the payjoin transaction → the negotiation completed;
  /// - it IS the original transaction → the payjoin was aborted and the
  ///   payment fell back to a plain broadcast.
  /// Falls back to the session status when there is no wallet transaction
  /// (nothing broadcast yet, or not synced in) — and null when this
  /// transaction has no payjoin at all.
  PayjoinStatus? get displayPayjoinStatus {
    final pj = payjoin;
    if (pj == null) return null;
    final walletTxId = walletTransaction?.txId;
    if (walletTxId != null) {
      if (walletTxId == pj.txId) return PayjoinStatus.completed;
      if (walletTxId == pj.originalTxId && !pj.isCompleted) {
        return PayjoinStatus.aborted;
      }
    }
    return pj.status;
  }

  /// The mining fee (sats) deducted from a completed payjoin receive,
  /// paying for the input the receiver contributed to the transaction
  /// (BIP78). `null` unless this is a payjoin actually reflected in a
  /// broadcast transaction, on the receive side, with a positive gap
  /// between the amount the sender negotiated ([Payjoin.amountSat]) and the
  /// amount the wallet actually sees ([WalletTransaction.amountSat]).
  ///
  /// The applicability check deliberately mirrors the existing "is this
  /// payjoin done" display heuristic used elsewhere
  /// (transaction_details_table.dart's status row: isCompleted ||
  /// (proposed && the broadcast tx IS the proposal)) rather than a strict
  /// `isCompleted` check: without the receiver-side watch-for-broadcast
  /// this branch doesn't add, a receiver session may never reach
  /// `completed` even once its real payjoin transaction has landed in the
  /// wallet — a strict check would never show this row for a receiver at
  /// all. The proposed case additionally requires the wallet transaction's
  /// txid to match the session's proposal txid: sessions are also joined
  /// to their ORIGINAL transaction (see LocalPayjoinDatasource.fetchByTxId),
  /// and an original that landed on-chain is a plain fallback — no input
  /// was contributed, so no fee-contribution row must appear for it.
  int? get payjoinFeeContributionSat {
    final p = payjoin;
    final wt = walletTransaction;
    if (p is! PayjoinReceiverSession || wt == null) return null;
    final isRealPayjoinBroadcast =
        p.isCompleted ||
        (p.status == PayjoinStatus.proposed &&
            p.txId != null &&
            p.txId == wt.txId);
    if (!isRealPayjoinBroadcast) return null;
    final expectedAmountSat = p.amountSat;
    if (expectedAmountSat == null) return null;
    final gap = expectedAmountSat - wt.amountSat;
    return gap > 0 ? gap : null;
  }

  /// The sender's own fee share in a Payjoin transaction.
  ///
  /// BDK reports the whole transaction fee even though the receiver pays for
  /// some of the inputs it contributes. Reconstruct the sender's wallet debit
  /// and remove the negotiated payment amount so the UI never attributes the
  /// receiver's fee contribution to the sender.
  int? get payjoinSenderFeeSat {
    final p = payjoin;
    final wt = walletTransaction;
    if (p is! PayjoinSenderSession || wt == null || !wt.isOutgoing) return null;
    final senderFee = wt.amountSat + wt.feeSat - p.amountSat;
    return senderFee >= 0 ? senderFee : null;
  }

  bool get isOrder => order != null;
  bool get isBuyOrder => order is BuyOrder;
  bool get isSellOrder => order is SellOrder;
  bool get isWithdrawOrder => order is WithdrawOrder;
  bool get isPayOrder => order is FiatPaymentOrder;
  bool get isFundingOrder => order is FundingOrder;
  bool get isRewardOrder => order is RewardOrder;
  bool get isRefundOrder => order is RefundOrder;
  bool get isBalanceAdjustmentOrder => order is BalanceAdjustmentOrder;
  bool get isOutgoing => walletTransaction != null
      ? walletTransaction!.isOutgoing
      : swap?.isLnSendSwap == true ||
            swap?.isChainSwap == true ||
            orderSwap?.sourceWalletId != null ||
            payjoin is PayjoinSenderSession;
  bool get isIncoming =>
      walletTransaction?.isIncoming ??
      swap?.isLnReceiveSwap == true ||
          swap?.isChainSwap == true ||
          orderSwap?.destinationWalletId != null ||
          payjoin is PayjoinReceiverSession ||
          order?.isIncoming == true;

  bool get isLnSwap =>
      (swap != null && (swap!.isLnReceiveSwap || swap!.isLnSendSwap)) ||
      orderSwap?.inNetwork == OrderSwapNetwork.lightning ||
      orderSwap?.outNetwork == OrderSwapNetwork.lightning;
  bool get isChainSwap =>
      (swap?.isChainSwap ?? false) || (orderSwap != null && !isLnSwap);
  bool get isLiquidToBitcoinSwap =>
      swap?.type == SwapType.liquidToBitcoin ||
      (orderSwap?.inNetwork == OrderSwapNetwork.liquid &&
          orderSwap?.outNetwork == OrderSwapNetwork.bitcoin);

  // Internal swaps are outgoing from one wallet and incoming to the other.
  bool isIncomingWallet(String? walletId) {
    final orderSwap = this.orderSwap;
    if (walletId != null && orderSwap != null) {
      return orderSwap.destinationWalletId == walletId &&
          orderSwap.sourceWalletId != walletId;
    }
    final swap = this.swap;
    if (walletId != null && swap is ChainSwap) {
      return swap.receiveWalletId == walletId && swap.sendWalletId != walletId;
    }
    return isIncoming;
  }

  DateTime? get timestamp =>
      // Completed swaps are displayed (and should sort) by when they finished,
      // not when they were created — otherwise a just-claimed rescued swap
      // (created long ago) lands far down the list under its old creation time.
      swap?.completionTime ??
      swap?.creationTime ??
      orderSwap?.order?.completedAt ??
      orderSwap?.createdAt ??
      payjoin?.createdAt ??
      order?.createdAt ??
      walletTransaction?.confirmationTime;

  int get amountSat =>
      payjoin?.amountSat ??
      walletTransaction?.amountSat ??
      (swap != null
          ? swap!.amountSat - (swap!.fees?.totalFees(swap!.amountSat) ?? 0)
          : 0);

  /// Headline amount for a swap on the transaction-details screen. A recovered
  /// swap shows the net on-chain [amountSat]; otherwise the directional figure
  /// (amount sent for outgoing, received for incoming; an external chain swap
  /// shows the received amount). Returns [amountSat] when this isn't a swap.
  int get swapDisplayAmountSat {
    final exchangeSwap = orderSwap;
    if (exchangeSwap != null) {
      return exchangeSwap.order?.payoutAmountSat.toInt() ??
          exchangeSwap.requestedAmountSat.toInt();
    }
    final s = swap;
    if (s == null || s.recovered) return amountSat;
    if (s is ChainSwap && s.receiveWalletId == null) {
      return s.receieveAmount ?? 0;
    }
    return isOutgoing ? s.amountSat : (s.receieveAmount ?? 0);
  }

  /// Headline amount for a swap in the transaction list. NOTE: intentionally
  /// differs from [swapDisplayAmountSat] for non-recovered swaps — the list
  /// shows the gross swap amount, the details screen the directional net. Kept
  /// separate to preserve existing display; converge if product wants them
  /// identical.
  int get swapListAmountSat {
    final exchangeSwap = orderSwap;
    if (exchangeSwap != null) {
      return exchangeSwap.order?.payoutAmountSat.toInt() ??
          exchangeSwap.requestedAmountSat.toInt();
    }
    final s = swap;
    if (s == null) return amountSat;
    return s.recovered ? amountSat : s.amountSat;
  }

  String get walletId =>
      walletTransaction?.walletId ??
      swap?.walletId ??
      orderSwap?.canonicalWalletId ??
      payjoin!.walletId;

  List<Label>? get labels => walletTransaction?.labels;
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
