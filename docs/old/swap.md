/// 1. WalletBloc.listTxs calls `WatchWalletTxs` for a specific wallet
/// 2. WatchWalletTxs
///   - gets swap txs from wallet given the wallet Id (ISSUE: Sometimes swap txs doesn't return all swaps)
///   - filters swap txs to narrow down only active swaps
///   - For settled swaps, calls
///     - `UpdateOrClaimSwap` (TODO: Why?)
///   - Calls WatchSwapStatus with the narrowed down swap list
/// 3. WatchSwapStatus
///   - combines incoming swap list with 'listeningTxs'
///   - Boltz.addSwapSubs() is called for the combined list
///     (POTENTIAL ISSUE: addSwapSubs should combine the swap list with it's own global swap list, which is a a union of all swap lists from all wallets)
///     - For each WSS update for the given swap list, `SwapStatusUpdate` is called
/// 4. SwapStatusUpdate
///   - This is called for swap status updates from WSS for each listening swaps
///   - For each swap status update, `UpdateOrClaimSwap` is called
/// 5. UpdateOrClaimSwap
///   - If Swap is (reverse and settled) or is (submbarine and status is txnMempool or txnConfirmed | ISSUE: Could also check for txnClaimed. right?),
///     - [Idea] Merge the swap with tx and remove it from wallet.swaps list
///     - Pick swapTx from claimedSwapTxs, if given swap.txid is null (ISSUE: Here swap.txid is null and not found in claimedSwapTxs)
///     - Merge the swap with wallet.tx by calling `walletTransaction.mergeSwapTxIntoTx`
///       - Remove the swap from wallet.swaps since the swap is like DONE now.
///       - Remove swap from secureStorage
///   - If Swap is not claimable
///     - update wallet.swaps[swapTx].txId with right txid and get refund swap list by calling `walletTransaction.updateSwapTxs`
///     - If refund swap list is empty, update wallet with swaps list and return
///   - If swap is claimed
///     - return
///   - In refund scenario, initiate refund and take txid
///   - In claim scenario, initiate claim and take txid
///   - Assign txid to swapTx and and add swap to claimedSwapTxs and update wallet