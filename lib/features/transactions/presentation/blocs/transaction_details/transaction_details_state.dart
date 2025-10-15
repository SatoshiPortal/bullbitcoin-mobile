part of 'transaction_details_cubit.dart';

@freezed
sealed class TransactionDetailsState with _$TransactionDetailsState {
  const factory TransactionDetailsState({
    Transaction? transaction,
    Wallet? wallet,
    Wallet? counterpartWallet,
    String? swapCounterpartTxId,
    String? note,
    @Default(false) bool isBroadcastingPayjoinOriginalTx,
    @Default(false) bool retryingSwap,
    TransactionNotFoundError? notFoundError,
    Object? err,
  }) = _TransactionDetailsState;
  const TransactionDetailsState._();

  bool get isLoading => transaction == null;

  WalletTransaction? get walletTransaction => transaction?.walletTransaction;
  Swap? get swap => transaction?.swap;
  Payjoin? get payjoin => transaction?.payjoin;

  bool get isOngoingSwap => transaction?.isOngoingSwap == true;

  /// Calculates the total aggregated fees for display in transaction details
  /// Takes into account the actual transaction fees paid
  int aggregateSwapFees() {
    final swap = this.swap;
    if (swap == null) return 0;

    final txFee = walletTransaction?.feeSat ?? 0;

    if (swap.type.isChain) {
      // For chain swaps: never add txFee to total transfer fees
      // txFee is shown separately in Network Fee breakdown
      return swap.fees?.totalFees(swap.amountSat) ?? 0;
    } else if (swap.type.isReverse) {
      // For reverse swaps: use original total fees logic
      return swap.fees?.totalFees(swap.amountSat) ?? 0;
    } else if (swap.type.isSubmarine) {
      // For submarine swaps: subtract lockupFee and add txFee
      final originalSwapFees = swap.fees?.totalFees(swap.amountSat) ?? 0;
      final lockupFee = swap.fees?.lockupFee ?? 0;
      return originalSwapFees - lockupFee + txFee;
    } else {
      return swap.fees?.totalFees(swap.amountSat) ?? 0;
    }
  }

  /// Calculates the network fee portion for display in transaction details
  /// Takes into account the actual transaction fees paid
  int aggregateNetworkFees() {
    final swap = this.swap;
    if (swap == null) return 0;

    final txFee = walletTransaction?.feeSat ?? 0;

    if (swap.type.isChain) {
      return (swap.fees?.lockupFee ?? 0) + (swap.fees?.claimFee ?? 0);
    } else if (swap.type.isReverse) {
      return (swap.fees?.lockupFee ?? 0) + (swap.fees?.claimFee ?? 0);
    } else if (swap.type.isSubmarine) {
      return txFee + (swap.fees?.claimFee ?? 0);
    } else {
      return (swap.fees?.lockupFee ?? 0) + (swap.fees?.claimFee ?? 0);
    }
  }

  /// Calculates the actual amount sent (received by recipient)
  /// For swaps: amount - txFee + aggregateSwapFees
  /// For regular transactions: amount - txFee
  int getAmountSent() {
    final swap = this.swap;
    final payjoin = this.payjoin;
    final txFee = walletTransaction?.feeSat ?? 0;
    final amount = walletTransaction?.amountSat;
    if (payjoin != null) {
      return payjoin.amountSat ?? 0;
    }

    if (swap != null && swap.type.isSubmarine) {
      if (amount != null) {
        return amount + txFee;
      } else {
        return swap.amountSat + aggregateSwapFees();
      }
    } else if (swap != null && swap.type.isChain) {
      return amount ?? 0 + aggregateNetworkFees();
    } else if (swap != null && swap.type.isReverse) {
      if (amount != null) {
        return amount + txFee;
      } else {
        return swap.amountSat + aggregateSwapFees();
      }
    } else {
      return amount ?? 0 + txFee;
    }
  }

  int getAmountReceived() {
    if (payjoin != null) {
      return payjoin?.amountSat ?? 0;
    }
    final amount = walletTransaction?.amountSat ?? 0;
    return amount;
  }

  /*
  bool
  get isOngoingPayjoin {
    final transaction = incomingTransaction ?? outgoingTransaction!;
  }
      incomingTransaction?.payjoin != null &&
      transaction!.payjoin!.isOngoing &&
      // Todo: remove the following line once we put a payjoin to complete or failed
      // depending on watched transactions
      transaction?.walletTransaction?.txId ==
          transaction?.payjoin!.originalTxId;*/
}
