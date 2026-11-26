import 'dart:async';

import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart'
    show SyncCompletion, SyncFailure, SyncTransactionTarget, WalletKey;

import '../../transactions.dart';

final class AppPayjoinTransactionAdapter implements PayjoinTransactionPort {
  static const _reconcileAttempts = 3;

  final WalletInventory _wallets;
  final Future<Result<void, SyncFailure>> Function(WalletKey) _synchronize;
  final Future<Result<SyncCompletion, SyncFailure>> Function(
    WalletKey,
    List<SyncTransactionTarget>,
  )
  _synchronizeTargeted;
  final Stream<WalletKey> _finished;
  final Transactions _transactions;
  final Future<bool> Function(String, String) _protectSpend;
  // Pacing between two wallet syncs of [_reconcileWallet]; tests shorten it.
  final Duration reconcileDelay;

  const AppPayjoinTransactionAdapter(
    this._wallets,
    this._transactions, {
    required this._synchronize,
    required this._synchronizeTargeted,
    required this._finished,
    required this._protectSpend,
    this.reconcileDelay = const Duration(seconds: 5),
  });

  @override
  Future<bool> protectObservedSpend({
    required String walletId,
    required String transactionId,
  }) => _protectSpend(walletId, transactionId);

  @override
  Stream<void> watchWallet(String walletId) => _finished
      .where((key) => key.id == walletId && key.network is BitcoinNetwork)
      .asyncMap(
        (key) async => switch (await _wallets.readWallet(key.id)) {
          Ok(:final value) => value.network == key.network,
          Err() => false,
        },
      )
      .where((admitted) => admitted)
      .map((_) {});

  /// A local read answers from the wallet's own copy, which is enough when a
  /// sync has just finished.
  ///
  /// A refreshed read takes the targeted pass instead: it asks the Electrum
  /// server only about the scripts these candidates pay and the outpoints they
  /// spend, instead of syncing the whole wallet, which takes 15 to 120 seconds
  /// over Tor and delayed every payjoin outcome by as much. Only that pass may
  /// answer `false`: a pending transaction the wallet saw earlier can since
  /// have been evicted or replaced, and the engine settles sessions on this
  /// answer.
  @override
  Future<Map<String, bool?>> transactionsPresence({
    required String walletId,
    required List<PayjoinTransaction> transactions,
    bool refresh = false,
  }) async {
    final answers = <String, bool?>{};
    if (!refresh) {
      for (final transaction in transactions) {
        answers[transaction.txid] = await _readTransaction(
          walletId,
          transaction.txid,
        );
      }
      return answers;
    }
    await _settleWithTargetedPass(walletId, transactions, answers);
    return answers;
  }

  /// One pass, one answer per candidate: true where the pass saw it land,
  /// false where the pass covered its scripts and did not, null everywhere
  /// else — a candidate sent as its id alone, a malformed candidate, a target
  /// the pass could not cover, or a pass that covered no script of this wallet
  /// at all, failed, or could not be reached.
  ///
  /// A wallet that cannot be read, or that is not Bitcoin, is refused before
  /// any target is built.
  Future<void> _settleWithTargetedPass(
    String walletId,
    List<PayjoinTransaction> transactions,
    Map<String, bool?> answers,
  ) async {
    final key = await _readKey(walletId);
    if (key.network is! BitcoinNetwork) {
      throw Exception('Payjoin requires a Bitcoin wallet');
    }
    final targets = <SyncTransactionTarget>[];
    for (final transaction in transactions) {
      answers[transaction.txid] = null;
      if (transaction.outputs.isEmpty && transaction.inputs.isEmpty) continue;
      try {
        targets.add(
          SyncTransactionTarget(
            txid: transaction.txid,
            outputScripts: [
              for (final output in transaction.outputs) output.scriptPubkey,
            ],
            spentOutpoints: transaction.inputs,
          ),
        );
      } on ArgumentError {
        // A malformed candidate cannot name a transaction a pass may judge.
        // It stays unknown without throwing, so it neither follows the
        // mutation nor keeps its valid peers from syncing.
      }
    }
    if (targets.isEmpty) return;
    try {
      final SyncCompletion completion;
      switch (await _synchronizeTargeted(key, targets)) {
        case Ok(:final value):
          completion = value;
        case Err(:final failure):
          log.warning(
            'Payjoin targeted sync failed category=${failure.logCode}',
          );
          return;
      }
      final visible = completion.visibleTransactionIds;
      final covered = completion.coveredTransactionIds;
      if (visible == null || covered == null) return;
      for (final target in targets) {
        // A target the pass could not cover stays unknown: only a covered one
        // may be answered, absent included.
        if (!covered.contains(target.txid)) continue;
        answers[target.txid] = visible.contains(target.txid);
      }
      if (visible.isNotEmpty) {
        unawaited(_reconcileWallet(walletId, visible));
      }
    } on Exception {
      // Every answer stays null: an unavailable pass proves nothing.
      log.warning('Payjoin targeted sync unavailable');
    }
  }

  /// Settles the wallet's own copy for the transactions a pass proved visible,
  /// a few times at most: the pass proved them on the server, and this only
  /// brings the row and the history the UI reads up to date. The session
  /// outcome never waits on this.
  Future<void> _reconcileWallet(String walletId, Set<String> txids) async {
    for (var attempt = 1; attempt <= _reconcileAttempts; attempt++) {
      if (attempt > 1) await Future<void>.delayed(reconcileDelay * attempt);
      try {
        await refreshWallet(walletId);
        var allSeen = true;
        for (final txid in txids) {
          if (await _readTransaction(walletId, txid) != true) {
            allSeen = false;
            break;
          }
        }
        if (allSeen) {
          if (attempt > 1) {
            log.fine('Payjoin wallet reconcile recovered attempts=$attempt');
          }
          return;
        }
      } on Exception {
        // The final outcome below owns this bounded reconciliation.
      }
    }
    log.warning(
      'Payjoin wallet reconcile failed attempts=$_reconcileAttempts reason=unavailable',
    );
  }

  Future<bool?> _readTransaction(String walletId, String transactionId) async {
    return switch (await _transactions.getWalletTransaction(
      transactionId,
      walletId: walletId,
    )) {
      Ok(:final value) => value != null,
      Err(:final failure) => _unavailable(failure),
    };
  }

  bool? _unavailable(TransactionFailure failure) {
    log.warning('Payjoin wallet history unavailable: ${failure.runtimeType}');
    return null;
  }

  @override
  Future<void> refreshWallet(String walletId) async {
    final result = await _synchronize(await _readKey(walletId));
    if (result case Err(:final failure)) {
      throw Exception('Payjoin wallet refresh failed: ${failure.logCode}');
    }
  }

  Future<WalletKey> _readKey(String id) async =>
      switch (await _wallets.readWallet(id)) {
        Ok(:final value) => WalletKey(id: value.id, network: value.network),
        Err(:final failure) => throw Exception(
          'Payjoin wallet unavailable: ${failure.runtimeType}',
        ),
      };
}
