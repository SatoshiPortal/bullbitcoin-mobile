part of 'transaction_details_cubit.dart';

@freezed
sealed class TransactionDetailsState with _$TransactionDetailsState {
  const factory TransactionDetailsState({
    Transaction? transaction,
    Wallet? wallet,
    Wallet? counterpartWallet,
    String? swapCounterpartTxId,
    // The exact amount claimed on a recovered chain swap's receive (claim) leg,
    // resolved by the cubit. Used as the received amount because the canonical
    // tx shown can be the lockup (send) leg, whose amount is what was sent.
    int? swapClaimedAmountSat,
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

    if (swap != null) {
      // Recovered swaps carry no sendAmount; when the linked tx is the lockup
      // (send) leg, its amount IS what was sent.
      if (swap.sendAmount != null) return swap.sendAmount!;
      if (walletTransaction?.isOutgoing == true) {
        return walletTransaction!.amountSat;
      }
      return 0;
    }
    return amount ?? 0 + txFee;
  }

  /// Send amount for the details row — null when genuinely unknown so the row
  /// is hidden rather than showing a misleading "0 sats". A loading state has
  /// no transaction yet, which also yields null (not a real zero).
  int? get displayAmountSentSat {
    if (isLoading) return null;
    final sent = getAmountSent();
    return sent > 0 ? sent : null;
  }

  int getAmountReceived() {
    if (payjoin != null) {
      return payjoin?.amountSat ?? 0;
    }
    // A recovered chain swap's canonical tx may be the lockup (send) leg, whose
    // amount is what was SENT. Use the exact amount the user received on the
    // counterpart leg (claim tx on a forward swap, refund tx on a refund).
    if (isRecoveredSwap && swapClaimedAmountSat != null) {
      return swapClaimedAmountSat!;
    }
    final amount = walletTransaction?.amountSat ?? 0;
    return amount;
  }

  bool get isRecoveredSwap => swap?.recovered == true;

  /// Recovered-swap fee breakdown (see Swap.recovered): only the Boltz % fee is
  /// trustworthy, so the remaining on-chain cost is derived as
  /// sent − received − boltz; the per-leg lockup/server fees are hidden.
  int get recoveredBoltzFeeSat => swap?.fees?.boltzFee ?? 0;
  int get recoveredNetworkFeeSat =>
      getAmountSent() - getAmountReceived() - recoveredBoltzFeeSat;

  /// "Send network fee" for a send/chain swap is the user's lockup tx fee:
  /// prefer the persisted lockupFee, else fall back to the linked lockup tx's
  /// actual fee (older swaps didn't record it).
  int? get swapSendNetworkFeeSat {
    final lockupFee = swap?.fees?.lockupFee ?? 0;
    return lockupFee > 0 ? lockupFee : walletTransaction?.feeSat;
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
