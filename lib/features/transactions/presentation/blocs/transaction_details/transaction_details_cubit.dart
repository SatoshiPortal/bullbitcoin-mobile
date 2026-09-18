import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_transaction_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart' show Label;
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/transactions/application/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/delete_transaction_note_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_payjoin_by_id_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_payjoin_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transaction_note_suggestions_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transaction_order_swap_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transaction_order_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transaction_swap_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transaction_wallet_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transactions_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/save_transaction_note_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/watch_transaction_order_swap_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/watch_transaction_swap_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_details_cubit.freezed.dart';
part 'transaction_details_state.dart';

class TransactionDetailsCubit extends Cubit<TransactionDetailsState> {
  TransactionDetailsCubit({
    required this._getTransactionWalletUsecase,
    required this._getTransactionsByTxIdUsecase,
    required this._getWalletTransactionUsecase,
    required this._getTransactionOrderSwapUsecase,
    required this._watchWalletTransactionByTxIdUsecase,
    required this._getTransactionSwapUsecase,
    required this._getPayjoinByIdUsecase,
    required this._getPayjoinByTxIdUsecase,
    required this._getTransactionOrderUsecase,
    required this._watchTransactionSwapUsecase,
    required this._watchPayjoinUsecase,
    required this._watchTransactionOrderSwapUsecase,
    required this._saveTransactionNoteUsecase,
    required this._deleteTransactionNoteUsecase,
    required this._getTransactionNoteSuggestionsUsecase,
    required this._broadcastOriginalTransactionUsecase,
  }) : super(const TransactionDetailsState());

  final GetTransactionWalletUsecase _getTransactionWalletUsecase;
  final GetTransactionsByTxIdUsecase _getTransactionsByTxIdUsecase;
  final GetWalletTransactionUsecase _getWalletTransactionUsecase;
  final GetTransactionOrderSwapUsecase _getTransactionOrderSwapUsecase;
  final WatchWalletTransactionByTxIdUsecase
  _watchWalletTransactionByTxIdUsecase;
  final GetTransactionSwapUsecase _getTransactionSwapUsecase;
  final GetPayjoinByIdUsecase _getPayjoinByIdUsecase;
  final GetPayjoinByTxIdUsecase _getPayjoinByTxIdUsecase;
  final GetTransactionOrderUsecase _getTransactionOrderUsecase;
  final WatchTransactionSwapUsecase _watchTransactionSwapUsecase;
  final WatchPayjoinUsecase _watchPayjoinUsecase;
  final WatchTransactionOrderSwapUsecase _watchTransactionOrderSwapUsecase;
  final SaveTransactionNoteUsecase _saveTransactionNoteUsecase;
  final DeleteTransactionNoteUsecase _deleteTransactionNoteUsecase;
  final GetTransactionNoteSuggestionsUsecase
  _getTransactionNoteSuggestionsUsecase;
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

    if (state.failure != null) {
      emit(state.copyWith(failure: null));
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
          .listen((result) {
            if (isClosed) return;
            switch (result) {
              case Ok():
                _loadDetailsByWalletTxId(txId, walletId: walletId);
              case Err(:final failure):
                emit(state.copyWith(failure: failure));
            }
          });
    }
  }

  Future<void> initByOrderSwapLocalId(String localId) async {
    _reload = () => _loadDetailsByOrderSwapLocalId(localId);
    await _loadDetailsByOrderSwapLocalId(localId);
    _orderSwapSubscription = _watchTransactionOrderSwapUsecase
        .execute(localId)
        .listen((result) {
          if (isClosed) return;
          switch (result) {
            case Ok(:final value):
              unawaited(_handleOrderSwapUpdate(value));
            case Err(:final failure):
              emit(state.copyWith(failure: failure));
          }
        });
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
            if (latestOrderSwap.canonicalWalletTransactionId != transactionId) {
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
          // A dead watcher degrades the screen to its last loaded state
          // rather than failing it, so it is logged and not surfaced.
          onError: (_) {
            if (_watchedOrderSwapTransactionId == transactionId) {
              _watchedOrderSwapTransactionId = null;
            }
            log.warning('Order swap wallet transaction watcher failed');
          },
        );
    _watchedOrderSwapTransactionId = transactionId;
  }

  Future<void> _loadDetailsByOrderSwapLocalId(String localId) async {
    final OrderSwapRecord orderSwap;
    switch (await _getTransactionOrderSwapUsecase.execute(localId)) {
      case Ok(:final value):
        orderSwap = value;
      case Err(:final failure):
        if (isClosed) return;
        emit(state.copyWith(failure: failure));
        return;
    }

    await _watchOrderSwapWalletTransaction(orderSwap);
    await _loadOrderSwapDetails(orderSwap);
  }

  Future<void> _loadOrderSwapDetails(OrderSwapRecord orderSwap) async {
    final walletId = orderSwap.canonicalWalletId;
    if (walletId == null) {
      if (isClosed) return;
      emit(state.copyWith(failure: const TransactionNotFoundFailure()));
      return;
    }
    final counterpartWalletId = orderSwap.sourceWalletId == walletId
        ? orderSwap.destinationWalletId
        : orderSwap.sourceWalletId;
    final transactionId = orderSwap.canonicalWalletTransactionId;
    // Every leg returns a Result, so `.wait` can no longer throw a
    // ParallelWaitError: a failed leg is inspected below like any other value.
    final (
      walletResult,
      counterpartWalletResult,
      walletTransactionResult,
    ) = await (
      _getTransactionWalletUsecase.execute(walletId),
      counterpartWalletId == null
          ? Future.value(const Ok<Wallet?, TransactionFailure>(null))
          : _getTransactionWalletUsecase.execute(counterpartWalletId),
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

    final Wallet? wallet;
    switch (walletResult) {
      case Ok(:final value):
        wallet = value;
      case Err(:final failure):
        if (isClosed) return;
        emit(state.copyWith(failure: failure));
        return;
    }
    // The counterpart wallet is decoration on this screen: a failed read
    // hides one row instead of failing the whole transaction.
    final counterpartWallet = switch (counterpartWalletResult) {
      Ok(:final value) => value,
      Err() => null,
    };

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
        failure: null,
      ),
    );
  }

  Future<void> _loadDetailsByWalletTxId(
    String txId, {
    required String walletId,
  }) async {
    final List<Transaction> transactionsWithTxId;
    switch (await _getTransactionsByTxIdUsecase.execute(txId)) {
      case Ok(:final value):
        transactionsWithTxId = [...value];
      case Err(:final failure):
        if (isClosed) return;
        emit(state.copyWith(failure: failure));
        return;
    }

    final transaction = transactionsWithTxId
        .where((tx) => tx.walletId == walletId)
        .firstOrNull;
    if (transaction == null) {
      if (isClosed) return;
      emit(state.copyWith(failure: const TransactionNotFoundFailure()));
      return;
    }

    final Wallet? wallet;
    switch (await _getTransactionWalletUsecase.execute(walletId)) {
      case Ok(:final value):
        wallet = value;
      case Err(:final failure):
        if (isClosed) return;
        emit(state.copyWith(failure: failure));
        return;
    }

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
      counterpartWallet = await _walletOrNull(
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
        counterpartWallet = await _walletOrNull(counterpartWalletId);
      }
    }

    final swapClaimedAmountSat = await _counterpartAmountForSwap(swap);
    if (isClosed) return;
    emit(
      state.copyWith(
        transaction: transaction,
        wallet: wallet,
        counterpartWallet: counterpartWallet,
        swapCounterpartTxId: swapCounterpartTxId,
        swapClaimedAmountSat: swapClaimedAmountSat,
        // A load that succeeded clears whatever failed before it, so a stale
        // failure cannot linger under an inline renderer after a
        // watcher-driven reload has moved the session forward.
        failure: null,
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
  }

  /// Nudges the wallet to pull in a just-broadcast transaction. Fire and
  /// forget: the watchers resolve the screen either way, so a failed sync is
  /// logged and never surfaced.
  Future<void> _syncWallet(String walletId) async {
    final result = await _getTransactionWalletUsecase.execute(
      walletId,
      sync: true,
    );
    if (result case Err(:final failure)) {
      log.warning('Failed to sync wallet: ${failure.logMessage}');
    }
  }

  /// Best-effort wallet read, for the wallets that only decorate a screen
  /// whose transaction already loaded — a failure hides a row instead of
  /// replacing correct data with an error.
  Future<Wallet?> _walletOrNull(String walletId) async {
    return switch (await _getTransactionWalletUsecase.execute(walletId)) {
      Ok(:final value) => value,
      Err() => null,
    };
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
        .listen((result) async {
          // The payjoin repository's timers outlive this cubit; an event can
          // arrive after close() (see ReceiveBloc/SendCubit's identical guard).
          if (isClosed) return;
          final PayjoinSession payjoin;
          switch (result) {
            case Ok(:final value):
              payjoin = value;
            case Err(:final failure):
              emit(state.copyWith(failure: failure));
              return;
          }
          await _loadDetailsByWalletTxId(txId, walletId: walletId);
          if (isClosed) return;
          if (!payjoin.isOngoing &&
              state.transaction?.walletTransaction == null) {
            unawaited(_syncWallet(walletId));
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

  /// Best-effort lookup: a missing amount is rendered as unknown rather than
  /// failing the screen, so the failure is discarded deliberately here.
  Future<int?> _amountForTxInWallet(String txId, String walletId) async {
    final txs = switch (await _getTransactionsByTxIdUsecase.execute(txId)) {
      Ok(:final value) => value,
      Err() => const <Transaction>[],
    };

    for (final t in txs) {
      if (t.walletId == walletId) {
        return t.walletTransaction?.amountSat;
      }
    }
    return txs.isEmpty ? null : txs.first.walletTransaction?.amountSat;
  }

  Future<void> initBySwapId(String swapId, {required String walletId}) async {
    _swapSubscription = _watchTransactionSwapUsecase.execute(swapId).listen((
      result,
    ) {
      if (isClosed) return;
      switch (result) {
        case Ok():
          unawaited(_loadDetailsBySwapId(swapId, walletId: walletId));
        case Err(:final failure):
          emit(state.copyWith(failure: failure));
      }
    });

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
    final Swap swap;
    switch (await _getTransactionSwapUsecase.execute(swapId)) {
      case Ok(:final value):
        swap = value;
      case Err(:final failure):
        if (isClosed) return;
        emit(state.copyWith(failure: failure));
        return;
    }

    final String? txId;
    if (swap is ChainSwap) {
      // For chain swaps, we need to get the transaction ID based on the wallet
      // ID, since we need to show the transaction from the correct
      // perspective/direction.
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

    final Wallet? wallet;
    switch (await _getTransactionWalletUsecase.execute(walletId)) {
      case Ok(:final value):
        wallet = value;
      case Err(:final failure):
        if (isClosed) return;
        emit(state.copyWith(failure: failure));
        return;
    }

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
        counterpartWallet = await _walletOrNull(counterpartWalletId);
      }
    }

    if (isClosed) return;
    emit(
      state.copyWith(
        transaction: Transaction(swap: swap),
        wallet: wallet,
        counterpartWallet: counterpartWallet,
        swapCounterpartTxId: swapCounterpartTxId,
        // See _loadDetailsByWalletTxId: a successful load clears the failure.
        failure: null,
      ),
    );
  }

  Future<void> initByPayjoinId(String payjoinId) async {
    // Cancel any prior subscription (a re-entry, or one armed by the
    //  by-wallet-tx path) before replacing it — otherwise the old listener
    //  leaks and keeps firing duplicate _loadDetailsByPayjoinId runs.
    _watchedPayjoinId = null;
    await _payjoinSubscription?.cancel();
    _payjoinSubscription = _watchPayjoinUsecase
        .execute(ids: [payjoinId])
        .listen((result) {
          if (isClosed) return;
          switch (result) {
            case Ok():
              unawaited(_loadDetailsByPayjoinId(payjoinId));
            case Err(:final failure):
              emit(state.copyWith(failure: failure));
          }
        });

    // Load the initial details of the payjoin.
    await _loadDetailsByPayjoinId(payjoinId);

    _reload ??= () => _loadDetailsByPayjoinId(payjoinId);
  }

  Future<void> initByPayjoinTxId(String txId) async {
    _reload ??= () => initByPayjoinTxId(txId);
    switch (await _getPayjoinByTxIdUsecase.execute(txId)) {
      case Ok(:final value):
        await initByPayjoinId(value.id);
        return;
      case Err(:final failure):
        if (isClosed) return;
        emit(state.copyWith(failure: failure));
    }
  }

  Future<void> _loadDetailsByPayjoinId(String payjoinId) async {
    final PayjoinSession payjoin;
    switch (await _getPayjoinByIdUsecase.execute(payjoinId)) {
      case Ok(:final value):
        payjoin = value;
      case Err(:final failure):
        if (isClosed) return;
        emit(state.copyWith(failure: failure));
        return;
    }

    // Render persisted session state immediately. A direct wallet sync can
    // take tens of seconds, but an aborted/completed transition is already
    // authoritative enough to update the title, status and button now.
    if (isClosed) return;
    emit(
      state.copyWith(
        transaction:
            state.transaction?.copyWith(payjoin: payjoin) ??
            Transaction(payjoin: payjoin),
        // This is the reload the payjoin watcher drives, so it is where a
        // stale broadcast failure would otherwise sit under the button after
        // the session has already moved on.
        failure: null,
      ),
    );

    var wallet = state.wallet;
    if (wallet == null) {
      switch (await _getTransactionWalletUsecase.execute(payjoin.walletId)) {
        case Ok(:final value):
          wallet = value;
        case Err(:final failure):
          if (isClosed) return;
          emit(state.copyWith(failure: failure));
          return;
      }
    }
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
      await _stopPayjoinTransactionWatchers();
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
      unawaited(_syncWallet(payjoin.walletId));
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
      // Nothing found for this txid is not a failure: try the next candidate.
      final transactions = switch (await _getTransactionsByTxIdUsecase.execute(
        txId,
      )) {
        Ok(:final value) => value,
        Err() => const <Transaction>[],
      };
      final isVisibleInWallet = transactions.any(
        (tx) => tx.walletId == payjoin.walletId && tx.walletTransaction != null,
      );
      if (isVisibleInWallet) return txId;
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
    await _stopPayjoinTransactionWatchers();
    if (isClosed) return;
    final latestPayjoin = switch (await _getPayjoinByIdUsecase.execute(
      payjoin.id,
    )) {
      Ok(:final value) => value,
      // The session was already rendered above; keep what we have rather
      // than failing a screen that is showing correct data.
      Err() => payjoin,
    };
    if (isClosed) return;
    // The transaction is already resolved; a failed wallet read hides the
    // wallet row rather than replacing a correct screen with an error.
    final wallet = state.wallet ?? await _walletOrNull(latestPayjoin.walletId);
    if (isClosed) return;
    emit(
      state.copyWith(
        transaction: Transaction(
          walletTransaction: broadcast.walletTransaction,
          payjoin: latestPayjoin,
        ),
        wallet: wallet,
        // Resolving to the broadcast transaction is a successful load.
        failure: null,
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

  Future<void> _stopPayjoinTransactionWatchers() async {
    _watchedPayjoinId = null;
    await _payjoinSubscription?.cancel();
    await _payjoinTxSubscription?.cancel();
    await _payjoinOriginalTxSubscription?.cancel();
    _payjoinSubscription = null;
    _payjoinTxSubscription = null;
    _payjoinOriginalTxSubscription = null;
  }

  Future<void> initByOrderId(String orderId) async {
    await _loadDetailsByOrderId(orderId);

    // Only when the order didn't resolve to a wallet tx, which sets its own
    // reload without re-subscribing the watchers.
    _reload ??= () => _loadDetailsByOrderId(orderId);
  }

  Future<void> _loadDetailsByOrderId(String orderId) async {
    final Order order;
    switch (await _getTransactionOrderUsecase.execute(orderId)) {
      case Ok(:final value):
        order = value;
      case Err(:final failure):
        if (isClosed) return;
        emit(state.copyWith(failure: failure));
        return;
    }

    // Check if a transaction with the same transaction ID can be found
    // and initialize the transaction details with it.
    // The payjoin txid is the fallback: the exchange can know the payjoin it
    // broadcast before it reports its own payout txid, and without this the
    // screen would sit on order-only details until that txid lands.
    final txId = order.transactionId ?? order.payjoin?.txid;
    if (txId != null) {
      // A failed transaction lookup is not fatal here: fall through and show
      // the order details on their own.
      final txs = switch (await _getTransactionsByTxIdUsecase.execute(txId)) {
        Ok(:final value) => value,
        Err() => const <Transaction>[],
      };
      if (txs.isNotEmpty) {
        await initByWalletTxId(txId, walletId: txs.first.walletId);
        return;
      }
    }

    if (isClosed) return;
    emit(state.copyWith(transaction: Transaction(order: order), failure: null));
  }

  /// Returns the outcome so the caller can surface it, the same way
  /// [deleteTransactionNote] does. A note failure must not go into
  /// `state.failure`: nothing renders that once a transaction is on screen, so
  /// it would fail silently.
  @useResult
  Future<Result<Null, TransactionFailure>> saveTransactionLabel(
    String note,
  ) async {
    // TODO: Permit multiple labels && labels for payjoin txs, so not only wallet txs (for example set on the original tx)
    //  I think the entity should be changed to Transaction instead of WalletTransaction for that
    if (state.walletTransaction == null) return const Ok(null);

    if (state.walletTransaction!.labels.length >= 10) {
      return const Err(TransactionLabelLimitFailure());
    }

    final Label storedLabel;
    switch (await _saveTransactionNoteUsecase.execute(
      transactionId: state.walletTransaction!.txId,
      label: note,
      origin: state.walletTransaction!.walletId,
    )) {
      case Ok(:final value):
        storedLabel = value;
      case Err(:final failure):
        // Never render an unsaved note as saved.
        return Err(failure);
    }
    if (isClosed) return const Ok(null);

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
    return const Ok(null);
  }

  bool broadcastPayjoinOriginalTx() {
    if (state.isBroadcastingPayjoinOriginalTx) return false;
    final payjoin = state.payjoin;
    if (payjoin == null || !payjoin.canManuallyBroadcastOriginal) return false;
    emit(state.copyWith(isBroadcastingPayjoinOriginalTx: true, failure: null));
    unawaited(_broadcastPayjoinOriginalTx(payjoin));
    return true;
  }

  Future<void> _broadcastPayjoinOriginalTx(PayjoinSession payjoin) async {
    final result = await _broadcastOriginalTransactionUsecase.execute(payjoin);
    if (isClosed) return;

    switch (result) {
      case Err(failure: TransactionPayjoinFallbackUnavailableFailure()):
        // Not a failed attempt: the original is simply gone. Re-read the
        // session so the screen shows why, instead of an error.
        await _loadDetailsByPayjoinId(payjoin.id);
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
      case Ok(:final value):
        emit(
          state.copyWith(
            transaction: state.transaction?.copyWith(payjoin: value),
          ),
        );
        // Enrich asynchronously: do not keep the screen loading while
        // Electrum indexes the broadcast.
        unawaited(_resolveBroadcastTransaction(value));
    }

    // Every branch falls through to here on purpose: no branch may return
    // early, or the action keeps its progress bar spinning forever.
    if (!isClosed) {
      emit(state.copyWith(isBroadcastingPayjoinOriginalTx: false));
    }
  }

  Future<bool> canBroadcastPayjoinOriginalTx() async {
    final payjoin = state.payjoin;
    return payjoin != null &&
        await _broadcastOriginalTransactionUsecase.canExecute(payjoin);
  }

  Future<void> _resolveBroadcastTransaction(PayjoinSession payjoin) async {
    final broadcast = await _syncBroadcastTransactionForPayjoin(payjoin);
    if (broadcast != null && !isClosed) {
      await _showBroadcastTransaction(payjoin, broadcast);
    }
  }

  /// Deletes a transaction note. Returns the [Result] so the caller can give
  /// the user feedback on failure; on success the note is dropped from state.
  Future<Result<Null, TransactionFailure>> deleteTransactionNote(
    Label note,
  ) async {
    final walletTransaction = state.walletTransaction;
    if (walletTransaction == null) return const Ok(null);

    final result = await _deleteTransactionNoteUsecase.execute(note.id);
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

  Future<Set<String>> fetchDistinctLabels() =>
      _getTransactionNoteSuggestionsUsecase.execute();
}
