import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_transaction_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_error.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transactions_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_payjoin_by_id_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_payjoin_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/watch_payjoin_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transaction_order_swap_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/watch_transaction_order_swap_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_details_cubit.freezed.dart';
part 'transaction_details_state.dart';

class TransactionDetailsCubit extends Cubit<TransactionDetailsState> {
  TransactionDetailsCubit({
    required this._getWalletUsecase,
    required this._getTransactionsByTxIdUsecase,
    required this._getWalletTransactionUsecase,
    required this._getTransactionOrderSwapUsecase,
    required this._watchWalletTransactionByTxIdUsecase,
    required this._getSwapUsecase,
    required this._getPayjoinByIdUsecase,
    required this._getPayjoinByTxIdUsecase,
    required this._getOrderUsecase,
    required this._watchSwapUsecase,
    required this._watchPayjoinUsecase,
    required this._watchTransactionOrderSwapUsecase,
    required this._labelsFacade,
    required this._broadcastOriginalTransactionUsecase,
  }) : super(const TransactionDetailsState());

  final GetWalletUsecase _getWalletUsecase;
  final GetTransactionsByTxIdUsecase _getTransactionsByTxIdUsecase;
  final GetWalletTransactionUsecase _getWalletTransactionUsecase;
  final GetTransactionOrderSwapUsecase _getTransactionOrderSwapUsecase;
  final WatchWalletTransactionByTxIdUsecase
  _watchWalletTransactionByTxIdUsecase;
  final GetSwapUsecase _getSwapUsecase;
  final GetPayjoinByIdUsecase _getPayjoinByIdUsecase;
  final GetPayjoinByTxIdUsecase _getPayjoinByTxIdUsecase;
  final GetOrderUsecase _getOrderUsecase;
  final WatchSwapUsecase _watchSwapUsecase;
  final WatchPayjoinUsecase _watchPayjoinUsecase;
  final WatchTransactionOrderSwapUsecase _watchTransactionOrderSwapUsecase;
  final LabelsFacade _labelsFacade;
  final BroadcastOriginalTransactionUsecase
  _broadcastOriginalTransactionUsecase;

  /// The load that populated this cubit, so [refresh] can re-run it whichever
  /// init path the screen used. Orders only load once (they have no watcher),
  /// which is why the screen needs a way to ask for fresh data.
  Future<void> Function()? _reload;

  StreamSubscription? _walletTransactionSubscription;
  StreamSubscription? _swapSubscription;
  StreamSubscription? _payjoinSubscription;
  StreamSubscription? _payjoinTxSubscription;
  StreamSubscription? _payjoinOriginalTxSubscription;
  StreamSubscription? _orderSwapSubscription;
  String? _watchedOrderSwapTransactionId;
  WalletTransaction? _pendingOrderSwapWalletTransaction;
  int _orderSwapTransactionWatchGeneration = 0;

  // The payjoin id _payjoinSubscription is currently listening to on the
  // by-wallet-tx path, so reloads triggered by its own events don't
  // needlessly cancel and re-create the same subscription.
  String? _watchedPayjoinId;

  @override
  Future<void> close() async {
    await Future.wait([
      _walletTransactionSubscription?.cancel() ?? Future.value(),
      _swapSubscription?.cancel() ?? Future.value(),
      _payjoinSubscription?.cancel() ?? Future.value(),
      _payjoinTxSubscription?.cancel() ?? Future.value(),
      _payjoinOriginalTxSubscription?.cancel() ?? Future.value(),
      _orderSwapSubscription?.cancel() ?? Future.value(),
    ]);
    return super.close();
  }

  /// Re-runs the load that populated the details, for pull-to-refresh and for
  /// retrying after a failed load.
  Future<void> refresh() async {
    final reload = _reload;
    if (reload == null) return;

    if (state.err != null || state.notFoundError != null) {
      emit(state.copyWith(err: null, notFoundError: null));
    }
    await reload();
  }

  Future<void> initByWalletTxId(String txId, {required String walletId}) async {
    // Keep the reload of whichever init the screen started with: an order that
    // resolves to a wallet tx delegates here, and reloading the wallet tx also
    // refetches the order.
    _reload ??= () => _loadDetailsByWalletTxId(txId, walletId: walletId);

    // An order-id entry whose order only later gains a transactionId re-enters
    // here on every refresh, so drop the previous watcher instead of leaking a
    // live one that keeps fetching per wallet-tx event.
    await _walletTransactionSubscription?.cancel();

    // Start monitoring the wallet transaction for updates.
    _walletTransactionSubscription = _watchWalletTransactionByTxIdUsecase
        .execute(txId: txId, walletId: walletId)
        .listen((_) => _loadDetailsByWalletTxId(txId, walletId: walletId));

    // Load the initial details of the transaction.
    await _loadDetailsByWalletTxId(txId, walletId: walletId);
    final orderSwap = state.transaction?.orderSwap;
    if (orderSwap != null) {
      _orderSwapSubscription = _watchTransactionOrderSwapUsecase
          .execute(orderSwap.localId)
          .listen(
            (_) {
              if (isClosed) return;
              _loadDetailsByWalletTxId(txId, walletId: walletId);
            },
            onError: (Object error) {
              if (isClosed) return;
              emit(state.copyWith(err: error));
            },
          );
    }
  }

  Future<void> initByOrderSwapLocalId(String localId) async {
    _reload = () => _loadDetailsByOrderSwapLocalId(localId);
    await _loadDetailsByOrderSwapLocalId(localId);
    _orderSwapSubscription = _watchTransactionOrderSwapUsecase
        .execute(localId)
        .listen(
          (orderSwap) {
            unawaited(_handleOrderSwapUpdate(orderSwap));
          },
          onError: (Object error) {
            if (isClosed) return;
            emit(state.copyWith(err: error));
          },
        );
  }

  Future<void> _handleOrderSwapUpdate(OrderSwapRecord orderSwap) async {
    if (isClosed) return;
    final transaction = state.transaction;
    if (transaction?.orderSwap?.localId != orderSwap.localId) {
      await _loadDetailsByOrderSwapLocalId(orderSwap.localId);
      await _watchOrderSwapWalletTransaction(state.transaction?.orderSwap);
      return;
    }
    final walletTransaction = transaction?.walletTransaction;
    final canonicalTransactionChanged =
        walletTransaction != null &&
        walletTransaction.txId != orderSwap.canonicalWalletTransactionId;
    emit(
      state.copyWith(
        transaction: transaction!.copyWith(
          walletTransaction: canonicalTransactionChanged
              ? null
              : walletTransaction,
          orderSwap: orderSwap,
        ),
        swapCounterpartTxId: orderSwap.counterpartTransactionId,
      ),
    );
    await _watchOrderSwapWalletTransaction(orderSwap);
  }

  Future<void> _watchOrderSwapWalletTransaction(
    OrderSwapRecord? orderSwap,
  ) async {
    final transactionId = orderSwap?.canonicalWalletTransactionId;
    final walletId = orderSwap?.canonicalWalletId;
    if (transactionId == null || walletId == null) return;
    if (_watchedOrderSwapTransactionId == transactionId) return;
    final generation = ++_orderSwapTransactionWatchGeneration;
    _pendingOrderSwapWalletTransaction = null;
    await _walletTransactionSubscription?.cancel();
    if (isClosed || generation != _orderSwapTransactionWatchGeneration) return;
    try {
      _walletTransactionSubscription = _watchWalletTransactionByTxIdUsecase
          .execute(txId: transactionId, walletId: walletId)
          .listen(
            (walletTransaction) {
              if (isClosed) return;
              final latestOrderSwap = state.transaction?.orderSwap;
              if (latestOrderSwap == null) {
                _pendingOrderSwapWalletTransaction = walletTransaction;
                return;
              }
              if (latestOrderSwap.canonicalWalletTransactionId !=
                  transactionId) {
                return;
              }
              emit(
                state.copyWith(
                  transaction: state.transaction?.copyWith(
                    walletTransaction: walletTransaction,
                  ),
                ),
              );
            },
            onError: (_) {
              if (_watchedOrderSwapTransactionId == transactionId) {
                _watchedOrderSwapTransactionId = null;
              }
              log.warning('Order swap wallet transaction watcher failed');
            },
          );
      _watchedOrderSwapTransactionId = transactionId;
    } catch (_) {
      _watchedOrderSwapTransactionId = null;
      log.warning('Order swap wallet transaction watcher failed');
    }
  }

  Future<void> _loadDetailsByOrderSwapLocalId(String localId) async {
    try {
      final orderSwap = await _getTransactionOrderSwapUsecase.execute(localId);
      await _watchOrderSwapWalletTransaction(orderSwap);
      await _loadOrderSwapDetails(orderSwap);
    } on ParallelWaitError catch (error) {
      if (isClosed) return;
      emit(state.copyWith(err: _firstParallelError(error)));
    } on TransactionNotFoundError catch (error) {
      if (isClosed) return;
      emit(state.copyWith(notFoundError: error));
    } catch (error) {
      if (isClosed) return;
      emit(state.copyWith(err: error));
    }
  }

  Future<void> _loadOrderSwapDetails(OrderSwapRecord orderSwap) async {
    final walletId = orderSwap.canonicalWalletId;
    if (walletId == null) {
      if (isClosed) return;
      emit(state.copyWith(err: TransactionNotFoundError()));
      return;
    }
    final counterpartWalletId = orderSwap.sourceWalletId == walletId
        ? orderSwap.destinationWalletId
        : orderSwap.sourceWalletId;
    final transactionId = orderSwap.canonicalWalletTransactionId;
    final (wallet, counterpartWallet, walletTransactionResult) = await (
      _getWalletUsecase.execute(walletId),
      counterpartWalletId == null
          ? Future<Wallet?>.value()
          : _getWalletUsecase.execute(counterpartWalletId),
      transactionId == null
          ? Future.value(
              const Ok<WalletTransaction?, WalletTransactionLookupFailure>(
                null,
              ),
            )
          : _getWalletTransactionUsecase.execute(
              txId: transactionId,
              walletId: walletId,
            ),
    ).wait;
    final loadedWalletTransaction = switch (walletTransactionResult) {
      Ok(:final value) => value,
      Err() => () {
        log.warning('Order swap wallet transaction lookup failed');
        return null;
      }(),
    };
    final pendingWalletTransaction = _pendingOrderSwapWalletTransaction;
    _pendingOrderSwapWalletTransaction = null;
    final matchingPendingWalletTransaction =
        pendingWalletTransaction?.txId == transactionId &&
            pendingWalletTransaction?.walletId == walletId
        ? pendingWalletTransaction
        : null;
    final walletTransaction =
        matchingPendingWalletTransaction ?? loadedWalletTransaction;
    if (isClosed) return;
    emit(
      state.copyWith(
        transaction: Transaction(
          walletTransaction: walletTransaction,
          orderSwap: orderSwap,
        ),
        wallet: wallet,
        counterpartWallet: counterpartWallet,
        swapCounterpartTxId: orderSwap.counterpartTransactionId,
        err: null,
        notFoundError: null,
      ),
    );
  }

  Object _firstParallelError(ParallelWaitError error) {
    final errors = error.errors as (AsyncError?, AsyncError?, AsyncError?);
    return (errors.$1 ?? errors.$2 ?? errors.$3)?.error ?? error;
  }

  Future<void> _loadDetailsByWalletTxId(
    String txId, {
    required String walletId,
  }) async {
    try {
      final transactionsWithTxId = await _getTransactionsByTxIdUsecase.execute(
        txId,
      );
      final transaction = transactionsWithTxId.firstWhere(
        (tx) => tx.walletId == walletId,
        orElse: () => throw TransactionNotFoundError(),
      );
      final wallet = await _getWalletUsecase.execute(walletId);

      Wallet? counterpartWallet;
      final swap = transaction.swap;
      String? swapCounterpartTxId;
      // Retain only transactions that are not the same wallet and
      // have the opposite isIncoming value.
      // This is to find the counterpart wallet for the transaction.
      transactionsWithTxId.retainWhere(
        (t) => t.walletId != walletId && t.isIncoming != transaction.isIncoming,
      );
      if (transactionsWithTxId.isNotEmpty) {
        // If a transaction is found, get the wallet for it.
        counterpartWallet = await _getWalletUsecase.execute(
          transactionsWithTxId.first.walletId,
        );
      } else if (swap is ChainSwap) {
        swapCounterpartTxId = walletId == swap.sendWalletId
            ? swap.receiveTxId
            : swap.sendTxId;
        final counterpartWalletId = walletId == swap.sendWalletId
            ? swap.receiveWalletId
            : swap.sendWalletId;
        if (counterpartWalletId != null) {
          counterpartWallet = await _getWalletUsecase.execute(
            counterpartWalletId,
          );
        }
      }

      emit(
        state.copyWith(
          transaction: transaction,
          wallet: wallet,
          counterpartWallet: counterpartWallet,
          swapCounterpartTxId: swapCounterpartTxId,
          swapClaimedAmountSat: await _counterpartAmountForSwap(swap),
        ),
      );

      // If this transaction belongs to a payjoin session, keep the details
      // live on payjoin events too — not just on wallet syncs. The session's
      // terminal transitions (fallback broadcast, completion on broadcast)
      // happen in the payjoin repository long after this screen was opened,
      // and without this the screen only refreshed on the next wallet sync
      // (observed live: a stale "Send without payjoin" button lingering for
      // ~a minute after the fallback had already broadcast the original).
      final payjoin = transaction.payjoin;
      if (payjoin != null) {
        _watchPayjoinForWalletTx(
          payjoinId: payjoin.id,
          txId: txId,
          walletId: walletId,
        );
      }
    } on TransactionNotFoundError catch (e) {
      emit(state.copyWith(notFoundError: e));
    } catch (e) {
      emit(state.copyWith(err: e));
    }
  }

  /// Reloads the by-wallet-tx details whenever the given payjoin session
  /// emits an update. Payjoin state lives in the local database, so the
  /// reload is instant — the manual-broadcast button and the payjoin status
  /// row react the moment the repository resolves the session instead of
  /// waiting for a wallet sync to trigger the transaction watcher.
  ///
  /// On a terminal event (aborted/completed/expired) a targeted sync of this
  /// wallet is also fired when the broadcast transaction isn't visible as a
  /// wallet transaction yet, so the screen swaps from payjoin-only data to
  /// the real transaction promptly instead of at the next scheduled sync.
  void _watchPayjoinForWalletTx({
    required String payjoinId,
    required String txId,
    required String walletId,
  }) {
    if (_watchedPayjoinId == payjoinId) return;
    _watchedPayjoinId = payjoinId;
    unawaited(_payjoinSubscription?.cancel());
    _payjoinSubscription = _watchPayjoinUsecase
        .execute(ids: [payjoinId])
        .listen((payjoin) async {
          // The payjoin repository's timers outlive this cubit; an event can
          // arrive after close() (see ReceiveBloc/SendCubit's identical guard).
          if (isClosed) return;
          await _loadDetailsByWalletTxId(txId, walletId: walletId);
          if (isClosed) return;
          if (!payjoin.isOngoing &&
              state.transaction?.walletTransaction == null) {
            unawaited(
              _getWalletUsecase.execute(walletId, sync: true).catchError((
                Object e,
              ) {
                log.warning('Failed to sync wallet after payjoin event: $e');
                return null;
              }),
            );
          }
        });
  }

  /// The exact amount returned on the recovered chain swap's *counterpart* leg —
  /// what the user actually received. The canonical tx shown from the send
  /// wallet is the lockup leg (its amount is what was SENT), so the received
  /// figure comes from the other leg: the claim tx on a forward swap, or the
  /// refund tx on a refunded swap. Returns null when not a recovered chain swap
  /// or that leg isn't available yet.
  Future<int?> _counterpartAmountForSwap(Swap? swap) async {
    return await _claimedAmountForSwap(swap) ??
        await _refundedAmountForSwap(swap);
  }

  /// Forward (claim) leg: `receiveTxId` in the receive wallet.
  Future<int?> _claimedAmountForSwap(Swap? swap) async {
    if (swap is! ChainSwap || !swap.recovered) return null;
    final receiveTxId = swap.receiveTxId;
    final receiveWalletId = swap.receiveWalletId;
    if (receiveTxId == null || receiveWalletId == null) return null;
    return _amountForTxInWallet(receiveTxId, receiveWalletId);
  }

  /// Refund leg: the refund spends the lockup back to the SOURCE (send) chain,
  /// so the returned amount is the refund tx's incoming amount in the send
  /// wallet (lockup minus the refund tx fee).
  Future<int?> _refundedAmountForSwap(Swap? swap) async {
    if (swap is! ChainSwap || !swap.recovered) return null;
    final refundTxId = swap.refundTxId;
    if (refundTxId == null) return null;
    return _amountForTxInWallet(refundTxId, swap.sendWalletId);
  }

  Future<int?> _amountForTxInWallet(String txId, String walletId) async {
    try {
      final txs = await _getTransactionsByTxIdUsecase.execute(txId);
      for (final t in txs) {
        if (t.walletId == walletId) {
          return t.walletTransaction?.amountSat;
        }
      }
      return txs.isEmpty ? null : txs.first.walletTransaction?.amountSat;
    } catch (_) {
      return null;
    }
  }

  Future<void> initBySwapId(String swapId, {required String walletId}) async {
    _swapSubscription = _watchSwapUsecase
        .execute(swapId)
        .listen((_) => _loadDetailsBySwapId(swapId, walletId: walletId));

    // Load the initial details of the swap.
    await _loadDetailsBySwapId(swapId, walletId: walletId);

    // Only when the swap didn't resolve to a wallet tx, which sets its own
    // reload without re-subscribing the watchers.
    _reload ??= () => _loadDetailsBySwapId(swapId, walletId: walletId);
  }

  Future<void> _loadDetailsBySwapId(
    String swapId, {
    required String walletId,
  }) async {
    try {
      final swap = await _getSwapUsecase.execute(swapId);

      String? txId;
      if (swap is ChainSwap) {
        // For chain swaps, we need to get the transaction ID based on the wallet ID,
        //  since we need to show the transaction from the correct perspective/direction.
        txId = walletId == swap.sendWalletId ? swap.sendTxId : swap.receiveTxId;
      } else {
        // For other swaps, we can use the swap's transaction ID directly.
        txId = swap.txId;
      }

      if (txId != null) {
        await _swapSubscription?.cancel();
        await initByWalletTxId(txId, walletId: walletId);
        return;
      }

      final wallet = await _getWalletUsecase.execute(walletId);

      Wallet? counterpartWallet;
      String? swapCounterpartTxId;
      if (swap is ChainSwap) {
        swapCounterpartTxId = walletId == swap.sendWalletId
            ? swap.receiveTxId
            : swap.sendTxId;
        final counterpartWalletId = walletId == swap.sendWalletId
            ? swap.receiveWalletId
            : swap.sendWalletId;
        if (counterpartWalletId != null) {
          counterpartWallet = await _getWalletUsecase.execute(
            counterpartWalletId,
          );
        }
      }

      emit(
        state.copyWith(
          transaction: Transaction(swap: swap),
          wallet: wallet,
          counterpartWallet: counterpartWallet,
          swapCounterpartTxId: swapCounterpartTxId,
        ),
      );
    } catch (e) {
      emit(state.copyWith(err: e));
    }
  }

  Future<void> initByPayjoinId(String payjoinId) async {
    // Cancel any prior subscription (a re-entry, or one armed by the
    //  by-wallet-tx path) before replacing it — otherwise the old listener
    //  leaks and keeps firing duplicate _loadDetailsByPayjoinId runs.
    _watchedPayjoinId = null;
    await _payjoinSubscription?.cancel();
    _payjoinSubscription = _watchPayjoinUsecase
        .execute(ids: [payjoinId])
        .listen((_) => _loadDetailsByPayjoinId(payjoinId));

    // Load the initial details of the payjoin.
    await _loadDetailsByPayjoinId(payjoinId);

    _reload ??= () => _loadDetailsByPayjoinId(payjoinId);
  }

  Future<void> initByPayjoinTxId(String txId) async {
    _reload ??= () => initByPayjoinTxId(txId);
    try {
      final payjoin = await _getPayjoinByTxIdUsecase.execute(txId);
      await initByPayjoinId(payjoin.id);
    } catch (e) {
      emit(state.copyWith(err: e));
    }
  }

  Future<void> _loadDetailsByPayjoinId(String payjoinId) async {
    try {
      final payjoin = await _getPayjoinByIdUsecase.execute(payjoinId);

      // Render persisted session state immediately. A direct wallet sync can
      // take tens of seconds, but an aborted/completed transition is already
      // authoritative enough to update the title, status and button now.
      if (isClosed) return;
      emit(state.copyWith(transaction: Transaction(payjoin: payjoin)));

      final wallet =
          state.wallet ?? await _getWalletUsecase.execute(payjoin.walletId);
      if (isClosed) return;
      emit(state.copyWith(wallet: wallet));

      // Once a proposal exists, the negotiated txid is known. Query it
      // directly before the aggregate transaction loader, whose unrelated
      // exchange/swap lookups can be slow. This lets a receiver converge to
      // the sender's completed broadcast immediately.
      if (payjoin.txId != null) {
        final broadcast = await _syncBroadcastTransactionForPayjoin(payjoin);
        if (broadcast != null) {
          await _showBroadcastTransaction(payjoin, broadcast);
          return;
        }
      }

      // The broadcast transaction (the payjoin one, or the original on a
      // fallback) is usually already in the local wallet database by the
      // time this screen opens — the repository fires a targeted sync right
      // after any broadcast. Resolve it NOW instead of waiting for the next
      // organic sync to trigger the watchers below: without this the screen
      // sat on payjoin-session-only data (a stale "requested"/"proposed"
      // status and no transaction) even though the payment was already
      // on-chain (observed live on both sides of a fallback).
      var broadcastTxId = await _broadcastTxIdForPayjoin(payjoin);
      if (broadcastTxId == null && payjoin.txId == null && !payjoin.isOngoing) {
        // Resolved session whose broadcast isn't visible locally yet (the
        // user tapped "view details" within seconds of the broadcast, before
        // any sync pulled it in). Force a DIRECT sync'd lookup — the
        // repository's per-transaction sync path is not routed through the
        // sync coordinator, so it can't be throttled away — and wait for it,
        // so the user lands straight on the transaction view instead of a
        // payjoin-session placeholder that swaps out moments later
        // (observed live on the receiver side of an aborted payjoin). A
        // receiver with a published proposal also takes this path while its
        // persisted status is still in progress: it already knows the
        // negotiated txid, and the sender may have broadcast it while this
        // wallet was waiting for its background watcher.
        broadcastTxId = (await _syncBroadcastTransactionForPayjoin(
          payjoin,
        ))?.txId;
      }
      if (broadcastTxId != null) {
        // Reset so _loadDetailsByWalletTxId re-arms its own payjoin watcher
        // after this by-payjoin-id one is cancelled. Also cancel the two
        // per-txid watchers a previous pass may have armed — otherwise they
        // keep watching the same txid as _walletTransactionSubscription and
        // double-reload once it lands.
        _watchedPayjoinId = null;
        await _payjoinSubscription?.cancel();
        await _payjoinTxSubscription?.cancel();
        await _payjoinOriginalTxSubscription?.cancel();
        await initByWalletTxId(broadcastTxId, walletId: payjoin.walletId);
        return;
      }

      if (payjoin.txId != null) {
        // Listen for the payjoin transaction to be broadcasted.
        await _payjoinTxSubscription?.cancel();
        _payjoinTxSubscription = _watchWalletTransactionByTxIdUsecase
            .execute(txId: payjoin.txId!, walletId: payjoin.walletId)
            .listen((_) async {
              // An event can arrive around close() (the usecase stream and the
              //  repo's watchers outlive this cubit); never emit on a closed
              //  cubit (_loadDetailsByWalletTxId emits).
              if (isClosed) return;
              // Reset so _loadDetailsByWalletTxId re-arms its own payjoin
              // watcher after this by-payjoin-id one is cancelled.
              _watchedPayjoinId = null;
              await _payjoinSubscription?.cancel();
              await _loadDetailsByWalletTxId(
                payjoin.txId!,
                walletId: payjoin.walletId,
              );
            });
      }
      if (payjoin.originalTxId != null) {
        // Listen for the payjoin original transaction to be broadcasted.
        await _payjoinOriginalTxSubscription?.cancel();
        _payjoinOriginalTxSubscription = _watchWalletTransactionByTxIdUsecase
            .execute(txId: payjoin.originalTxId!, walletId: payjoin.walletId)
            .listen((_) async {
              // See the txId watcher above.
              if (isClosed) return;
              _watchedPayjoinId = null;
              await _payjoinSubscription?.cancel();
              await _loadDetailsByWalletTxId(
                payjoin.originalTxId!,
                walletId: payjoin.walletId,
              );
            });
      }

      // The session is resolved but its broadcast transaction isn't visible
      // in the local wallet database yet — fire a targeted sync so the
      // watchers armed above swap this screen to the real transaction
      // promptly instead of at the next scheduled sync (same gap
      // _watchPayjoinForWalletTx closes on the by-wallet-tx path).
      if (!payjoin.isOngoing) {
        unawaited(
          _getWalletUsecase.execute(payjoin.walletId, sync: true).catchError((
            Object e,
          ) {
            log.warning('Failed to sync wallet for resolved payjoin: $e');
            return null;
          }),
        );
      }
    } catch (e) {
      emit(state.copyWith(err: e));
    }
  }

  /// The txid of this payjoin session's transaction that actually reached
  /// the chain AND is already visible as a wallet transaction locally — the
  /// payjoin transaction when the negotiation completed, or the original
  /// transaction when the session fell back to a plain broadcast. Null while
  /// neither is visible yet (session still ongoing, or the wallet hasn't
  /// synced the broadcast in).
  Future<String?> _broadcastTxIdForPayjoin(PayjoinSession payjoin) async {
    for (final txId in [payjoin.txId, payjoin.originalTxId]) {
      if (txId == null) continue;
      try {
        final transactions = await _getTransactionsByTxIdUsecase.execute(txId);
        final isVisibleInWallet = transactions.any(
          (tx) =>
              tx.walletId == payjoin.walletId && tx.walletTransaction != null,
        );
        if (isVisibleInWallet) return txId;
      } catch (_) {
        // Nothing found for this txid — try the next candidate.
      }
    }
    return null;
  }

  /// Same candidates as [_broadcastTxIdForPayjoin], but each lookup forces a
  /// direct electrum-backed sync first, pulling a just-broadcast transaction
  /// into the local wallet database on demand. Bounded by one sync per
  /// candidate; best-effort — a failed lookup just means the watchers armed
  /// by the caller resolve it later.
  Future<({String txId, WalletTransaction walletTransaction})?>
  _syncBroadcastTransactionForPayjoin(PayjoinSession payjoin) async {
    for (final txId in [payjoin.txId, payjoin.originalTxId]) {
      if (txId == null) continue;
      final result = await _getWalletTransactionUsecase.execute(
        txId: txId,
        walletId: payjoin.walletId,
        sync: true,
      );
      switch (result) {
        case Ok(:final value):
          if (value != null) return (txId: txId, walletTransaction: value);
        case Err(:final failure):
          log.warning(
            'Forced lookup of payjoin broadcast tx failed: ${failure.logMessage}',
          );
      }
    }
    return null;
  }

  Future<void> _showBroadcastTransaction(
    PayjoinSession payjoin,
    ({String txId, WalletTransaction walletTransaction}) broadcast,
  ) async {
    if (isClosed) return;
    final latestPayjoin = await _getPayjoinByIdUsecase.execute(payjoin.id);
    if (isClosed) return;
    final wallet =
        state.wallet ?? await _getWalletUsecase.execute(latestPayjoin.walletId);
    if (isClosed) return;
    emit(
      state.copyWith(
        transaction: Transaction(
          walletTransaction: broadcast.walletTransaction,
          payjoin: latestPayjoin,
        ),
        wallet: wallet,
      ),
    );

    await _walletTransactionSubscription?.cancel();
    _walletTransactionSubscription = _watchWalletTransactionByTxIdUsecase
        .execute(txId: broadcast.txId, walletId: payjoin.walletId)
        .listen((_) {
          if (!isClosed) {
            unawaited(
              _loadDetailsByWalletTxId(
                broadcast.txId,
                walletId: payjoin.walletId,
              ),
            );
          }
        });
  }

  Future<void> initByOrderId(String orderId) async {
    await _loadDetailsByOrderId(orderId);

    // Only when the order didn't resolve to a wallet tx, which sets its own
    // reload without re-subscribing the watchers.
    _reload ??= () => _loadDetailsByOrderId(orderId);
  }

  Future<void> _loadDetailsByOrderId(String orderId) async {
    try {
      final order = await _getOrderUsecase.execute(orderId: orderId);

      // Check if a transaction with the same transaction ID can be found
      // and initialize the transaction details with it.
      final txId = order.transactionId;
      if (txId != null) {
        try {
          final txs = await _getTransactionsByTxIdUsecase.execute(txId);
          await initByWalletTxId(txId, walletId: txs.first.walletId);
          return;
        } catch (e) {
          // If an error occurs while fetching transactions, we can ignore it
          // and proceed with just the order details.
        }
      }

      emit(state.copyWith(transaction: Transaction(order: order)));
    } catch (e) {
      emit(state.copyWith(err: e));
    }
  }

  Future<void> saveTransactionLabel(NewLabel label) async {
    // TODO: Permit multiple labels && labels for payjoin txs, so not only wallet txs (for example set on the original tx)
    //  I think the entity should be changed to Transaction instead of WalletTransaction for that
    if (state.walletTransaction == null) return;

    if (state.walletTransaction!.labels.length >= 10) {
      emit(state.copyWith(err: 'You can only have up to 10 labels'));
      return;
    }

    final txLabel = NewLabel.tx(
      transactionId: state.walletTransaction!.txId,
      label: label.label,
      origin: state.walletTransaction!.walletId,
    );
    final Label storedLabel;
    switch (await _labelsFacade.store(txLabel)) {
      case Ok(:final value):
        storedLabel = value;
      case Err():
        // Persisting the note failed (logged at the boundary); leave the UI
        // unchanged rather than render an unsaved label as saved.
        return;
    }

    final updatedWalletransaction = state.transaction?.walletTransaction
        ?.copyWith(
          labels: [
            ...?state.transaction?.walletTransaction?.labels,
            storedLabel,
          ],
        );
    emit(
      state.copyWith(
        transaction: state.transaction?.copyWith(
          walletTransaction: updatedWalletransaction,
        ),
      ),
    );
  }

  Future<void> broadcastPayjoinOriginalTx() async {
    try {
      if (state.isBroadcastingPayjoinOriginalTx) return;
      final payjoin = state.payjoin;
      if (payjoin == null) return;
      // Fast local guard for completed/exchange sessions and receivers that do
      // not hold an original transaction. The engine performs the authoritative
      // refreshed mempool/blockchain check under the session lock.
      if (!payjoin.canManuallyBroadcastOriginal) return;
      emit(state.copyWith(isBroadcastingPayjoinOriginalTx: true, err: null));
      final updatedPayjoin = await _broadcastOriginalTransactionUsecase.execute(
        payjoin,
      );
      emit(
        state.copyWith(
          transaction: state.transaction?.copyWith(payjoin: updatedPayjoin),
        ),
      );

      // Resolve the fallback through the same path used when opening it from
      // All transactions, so full wallet transaction details appear as soon
      // as the wallet indexes the broadcast.
      // Do not keep the action or screen loading while Electrum indexes the
      // broadcast. The aborted session is already rendered above; enrich it
      // with full transaction details asynchronously.
      unawaited(_resolveBroadcastTransaction(updatedPayjoin));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(err: e));
    } finally {
      if (!isClosed) {
        emit(state.copyWith(isBroadcastingPayjoinOriginalTx: false));
      }
    }
  }

  Future<bool> canBroadcastPayjoinOriginalTx() async {
    final payjoin = state.payjoin;
    return payjoin != null &&
        await _broadcastOriginalTransactionUsecase.canExecute(payjoin);
  }

  Future<void> _resolveBroadcastTransaction(PayjoinSession payjoin) async {
    try {
      final broadcast = await _syncBroadcastTransactionForPayjoin(payjoin);
      if (broadcast != null && !isClosed) {
        await _showBroadcastTransaction(payjoin, broadcast);
      }
    } catch (e) {
      log.warning('Failed to resolve payjoin broadcast transaction: $e');
    }
  }

  /// Deletes a transaction note. Returns the [Result] so the caller can give
  /// the user feedback on failure; on success the note is dropped from state.
  Future<Result<Null, LabelFailure>> deleteTransactionNote(Label note) async {
    final walletTransaction = state.walletTransaction;
    if (walletTransaction == null) return const Ok(null);

    final result = await _labelsFacade.trash(note.id);
    if (result case Ok()) {
      final updatedLabels = [...?state.transaction?.walletTransaction?.labels];
      updatedLabels.remove(note);

      final updatedWalletTransaction = state.transaction?.walletTransaction
          ?.copyWith(labels: updatedLabels);
      emit(
        state.copyWith(
          transaction: state.transaction?.copyWith(
            walletTransaction: updatedWalletTransaction,
          ),
        ),
      );
    }
    // On Err the note is kept in state; the caller surfaces the failure.
    return result;
  }

  Future<Set<String>> fetchDistinctLabels() async {
    try {
      return await _labelsFacade.fetchDistinctLabels();
    } catch (e) {
      log.warning('Failed to fetch distinct labels: $e');
      emit(state.copyWith(err: e));
      return {};
    }
  }
}
