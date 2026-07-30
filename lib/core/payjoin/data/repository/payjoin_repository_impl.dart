import 'dart:async';

import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/payjoin/data/datasources/local_payjoin_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/datasources/pdk_payjoin_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/models/payjoin_input_pair_model.dart';
import 'package:bb_mobile/core/payjoin/data/models/payjoin_model.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart';
import 'package:bb_mobile/core/utils/constants.dart' show PayjoinConstants;
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:meta/meta.dart';
import 'package:synchronized/synchronized.dart';

class PayjoinRepositoryImpl implements PayjoinRepository {
  final LocalPayjoinDatasource _localPayjoinDatasource;
  final PdkPayjoinDatasource _pdkPayjoinDatasource;
  final WalletMetadataDatasource _walletMetadataDatasource;
  final SeedDatasource _seed;
  final BdkWalletDatasource _bdkWallet;
  final BdkBitcoinBlockchainDatasource _blockchain;
  final ElectrumServersPort _serversPort;
  // Lazy accessors keep this core repository independent from locator
  // registration order.
  final WalletRepository Function() _walletRepository;
  final WalletTransactionRepository Function() _walletTransactionRepository;
  final SettingsRepository _settingsRepository;
  // Lazy accessor, not a direct LabelsFacade, keeps registration order
  // independent.
  final LabelsFacade Function() _labelsFacade;
  // Shared across receiver sessions so two proposals cannot select the same
  // wallet UTXO before either proposal has been persisted.
  final Lock _utxoSelectionLock;
  final Lock _resumeLock;

  // All effects for one protocol session run in order. These locks are kept
  // until repository disposal so a lock is never replaced while callbacks are
  // queued on it.
  final Map<String, Lock> _sessionLocks = {};

  final StreamController<Payjoin> _payjoinStreamController;

  // Per-session subscriptions watching for a completed payjoin transaction to
  // appear on-chain, keyed by payjoin id. Kept so each can be cancelled once
  // its transaction is seen (the underlying watch stream re-emits on every
  // sync), on expiry, or on teardown. This is the only long-lived
  // subscription state in this otherwise fire-and-forget singleton, so its
  // hygiene lives entirely in _watchForBroadcast / _stopWatching / dispose.
  final Map<String, StreamSubscription<void>> _broadcastWatchers = {};

  // Per-session active-poll timers complementing _broadcastWatchers: each one
  // periodically forces a sync'd wallet-transaction lookup so completion does
  // not depend on some unrelated wallet sync happening to run (see
  // _watchForBroadcast). Keyed by payjoin id, cancelled together with the
  // passive watcher in _stopWatching / dispose.
  final Map<String, Timer> _broadcastPollTimers = {};

  // Mirrors _broadcastWatchers/_broadcastPollTimers but for the ORIGINAL
  // transaction instead of the real payjoin one — the safety net for
  // "the counterparty fell back independently and we'd otherwise never find
  // out" (see _watchForFallback). Armed as soon as originalTxId is known
  // (session creation for a sender, request-received for a receiver) and
  // runs alongside any later _watchForBroadcast for the same session:
  // whichever of the two lands on-chain first resolves the session, and
  // _stopWatching tears down both together.
  final Map<String, StreamSubscription<void>> _fallbackWatchers = {};
  final Map<String, Timer> _fallbackPollTimers = {};

  // Datasource stream subscriptions, cancelled on dispose.
  final List<StreamSubscription<void>> _datasourceSubscriptions = [];

  /// Delay between the automatic original-broadcast fallback retries (see
  /// [_broadcastOriginalWithRetry]). Mutable only so tests can zero it out to
  /// avoid real-time waits (and the timer bleed they cause across tests);
  /// production keeps the 1s default.
  @visibleForTesting
  Duration fallbackRetryDelay = const Duration(seconds: 1);

  PayjoinRepositoryImpl({
    required this._localPayjoinDatasource,
    required this._pdkPayjoinDatasource,
    required this._walletMetadataDatasource,
    required SeedDatasource seedDatasource,
    required BdkWalletDatasource bdkWalletDatasource,
    required BdkBitcoinBlockchainDatasource blockchainDatasource,
    required this._serversPort,
    required this._walletRepository,
    required this._walletTransactionRepository,
    required this._settingsRepository,
    required this._labelsFacade,
  }) : _seed = seedDatasource,
       _bdkWallet = bdkWalletDatasource,
       _blockchain = blockchainDatasource,
       _utxoSelectionLock = Lock(),
       _resumeLock = Lock(),
       _payjoinStreamController = StreamController<Payjoin>.broadcast() {
    // Listen to payjoin events from the datasource and process them
    _datasourceSubscriptions.addAll([
      _pdkPayjoinDatasource.requestsForReceivers.listen(_processPayjoinRequest),
      _pdkPayjoinDatasource.proposalsForSenders.listen(_processPayjoinProposal),
      _pdkPayjoinDatasource.expiredPayjoins.listen(_processExpiredPayjoin),
    ]);

    // The foreground composition root explicitly starts session recovery.
    // Registration alone must not start protocol work in background locators.
  }

  /// Releases all long-lived subscriptions and closes the payjoin stream.
  /// The production singleton lives for the whole app session and is never
  /// disposed, but tests (and any future teardown) need a clean exit.
  ///
  /// Also tears down the datasource so its per-session polling timers and
  /// event controllers don't outlive this repository — this repository owns
  /// the datasource's lifecycle (it's the sole subscriber to its streams).
  Future<void> dispose() async {
    for (final timer in _broadcastPollTimers.values) {
      timer.cancel();
    }
    _broadcastPollTimers.clear();
    for (final sub in _broadcastWatchers.values) {
      await sub.cancel();
    }
    _broadcastWatchers.clear();
    for (final timer in _fallbackPollTimers.values) {
      timer.cancel();
    }
    _fallbackPollTimers.clear();
    for (final sub in _fallbackWatchers.values) {
      await sub.cancel();
    }
    _fallbackWatchers.clear();
    for (final sub in _datasourceSubscriptions) {
      await sub.cancel();
    }
    _datasourceSubscriptions.clear();
    await _pdkPayjoinDatasource.dispose();
    await _payjoinStreamController.close();
  }

  @override
  Stream<Payjoin> get payjoinStream => _payjoinStreamController.stream;

  Future<T> _withSessionLock<T>(
    String payjoinId,
    Future<T> Function() action,
  ) => _sessionLocks.putIfAbsent(payjoinId, Lock.new).synchronized(action);

  @override
  Future<Payjoin?> getPayjoinById(String payjoinId) async {
    final (receiver, sender) = await (
      _localPayjoinDatasource.fetchReceiver(payjoinId),
      _localPayjoinDatasource.fetchSender(payjoinId),
    ).wait;
    if (receiver != null) {
      return receiver.toEntity();
    }
    if (sender != null) {
      return sender.toEntity();
    }
    // No payjoin found with the given ID
    return null;
  }

  @override
  Future<List<Payjoin>> getPayjoins({
    String? walletId,
    bool onlyOngoing = false,
    Environment? environment,
  }) async {
    final models = await _localPayjoinDatasource.fetchAll(
      walletId: walletId,
      onlyUnfinished: onlyOngoing,
      environment: environment,
    );

    final payjoins = models.map((model) => model.toEntity()).toList();

    return payjoins;
  }

  @override
  Future<List<Payjoin>> getPayjoinsByTxId(String txId) async {
    final payjoinModels = await _localPayjoinDatasource.fetchByTxId(txId);

    return payjoinModels
        .map((payjoinModel) => payjoinModel.toEntity())
        .toList();
  }

  @override
  Future<bool> checkOhttpRelayHealth() async {
    final (ohttpKeys, ohttpRelay) = await _pdkPayjoinDatasource
        .fetchOhttpKeyAndRelay(payjoinDirectory: PayjoinConstants.directoryUrl);
    return ohttpKeys != null && ohttpRelay != null;
  }

  // TODO: Remove this and use the general frozen utxo datasource
  @override
  Future<List<({String txId, int vout})>>
  getUtxosFrozenByOngoingPayjoins() async {
    final payjoins = await _localPayjoinDatasource.fetchAll(
      onlyUnfinished: true,
    );

    final inputs = await Future.wait(
      payjoins.map((payjoin) async {
        final psbt = payjoin is PayjoinReceiverModel
            ? payjoin.proposalPsbt
            : (payjoin as PayjoinSenderModel).originalPsbt;

        if (psbt == null) {
          return null;
        }

        final walletMetadata = await _walletMetadataDatasource.fetch(
          payjoin.walletId,
        );

        if (walletMetadata == null) {
          return null;
        }

        // Extract the spent utxos from the proposal psbt
        final proposalTx = await BitcoinTx.fromPsbt(psbt);
        final spentUtxos = proposalTx.inputs
            .map((input) => (txId: input.txid, vout: input.vout))
            .toList();
        return spentUtxos;
      }),
    );

    return inputs
        .whereType<List<({String txId, int vout})>>()
        .expand((element) => element)
        .toList();
  }

  @override
  Future<PayjoinReceiver> createPayjoinReceiver({
    required String walletId,
    required String address,
    required bool isTestnet,
    required BigInt maxFeeRateSatPerVb,
    required int expireAfterSec,
  }) async {
    final initialSettings = await _settingsRepository.fetch();
    if (!initialSettings.isPayjoinEnabled) {
      throw StateError('Payjoin is disabled');
    }

    final model = await _pdkPayjoinDatasource.createReceiver(
      walletId: walletId,
      address: address,
      isTestnet: isTestnet,
      maxFeeRateSatPerVb: maxFeeRateSatPerVb,
      expireAfterSec: expireAfterSec,
    );

    return _withSessionLock(model.id, () async {
      var stored = false;
      var settled = false;
      try {
        // Persist before the final settings check. A concurrent disable sweep
        // can now either see this row and wait for this lock, or finish first
        // and make the check below fail closed.
        await _localPayjoinDatasource.storeReceiver(model);
        stored = true;

        final settings = await _settingsRepository.fetch();
        if (!settings.isPayjoinEnabled) {
          await _settleReceiverAfterDisable(model);
          settled = true;
          throw StateError('Payjoin was disabled while creating the receiver');
        }

        return model.toEntity() as PayjoinReceiver;
      } catch (_) {
        _pdkPayjoinDatasource.stopPolling(model.id);
        if (stored && !settled) {
          // The row is still idle while this session lock is held. If another
          // path already settled it, the conditional delete is a no-op.
          await _localPayjoinDatasource.deleteIdleReceiver(model.id);
        }
        rethrow;
      }
    });
  }

  @override
  Future<PayjoinSender> createPayjoinSender({
    required String walletId,
    required bool isTestnet,
    required String bip21,
    required String originalPsbt,
    required int amountSat,
    required double networkFeesSatPerVb,
    int? expireAfterSec,
  }) => _withSessionLock(bip21, () async {
    // A sender id is the payment request itself. Reject a live or resolved
    // duplicate before posting another original proposal to the directory;
    // only an expired payment with no known broadcast outcome is retryable.
    final existing = await _localPayjoinDatasource.fetchSender(bip21);
    final canRetry =
        existing != null &&
        existing.isExpired &&
        !existing.isCompleted &&
        !existing.isAborted;
    if (existing != null && !canRetry) {
      throw StateError('A Payjoin session already exists for this payment');
    }

    final model = await _pdkPayjoinDatasource.createSender(
      walletId: walletId,
      isTestnet: isTestnet,
      bip21: bip21,
      originalPsbt: originalPsbt,
      networkFeesSatPerVb: networkFeesSatPerVb,
      amountSat: amountSat,
      expireAfterSec: expireAfterSec,
    );

    try {
      if (existing == null) {
        await _localPayjoinDatasource.storeSender(model);
      } else {
        final replaced = await _localPayjoinDatasource.replaceExpiredSender(
          model,
        );
        if (!replaced) {
          throw StateError('The expired Payjoin session could not be replaced');
        }
      }
    } catch (_) {
      _pdkPayjoinDatasource.stopPolling(model.id);
      rethrow;
    }

    _watchForFallback(
      payjoinId: model.id,
      walletId: model.walletId,
      originalTxId: model.originalTxId,
    );
    return model.toEntity() as PayjoinSender;
  });

  @override
  Future<Payjoin?> tryBroadcastOriginalTransaction(
    Payjoin payjoin,
  ) => _withSessionLock(payjoin.id, () async {
    // Idempotency/safety guard for MANUAL/external callers only (the
    // BroadcastOriginalTransactionUsecase invoked from
    // ReceiveBloc._onPayjoinOriginalTxBroadcasted and
    // TransactionDetailsCubit.broadcastPayjoinOriginalTx) — re-checked
    // against the freshest persisted state rather than trusting the
    // caller's possibly-stale copy, using the SAME canonical
    // Payjoin.canManuallyBroadcastOriginal getter those buttons' visibility
    // is gated on, so this can never disagree with what the UI decided to
    // show. Every one of those UI call sites SHOULD already gate on this
    // themselves, but this is cheap insurance against a stale UI snapshot
    // letting a tap through anyway — observed live: a sender's
    // already-completed-via-fallback session got a second "Send without
    // payjoin" tap ~10s later, re-broadcasting the same original psbt
    // (harmless here only because it was byte-for-byte identical to what
    // already confirmed). Had a REAL payjoin completed instead, this would
    // have re-broadcast a lower-fee transaction competing for the same
    // inputs as the already-broadcast payjoin tx — the exact dangerous RBF
    // race this guard exists to prevent.
    //
    // Deliberately NOT applied to this repository's own INTERNAL fallback
    // calls (_processPayjoinRequest, _processPayjoinProposal,
    // _processExpiredPayjoin all call _broadcastOriginalTransaction
    // directly, bypassing this): those run precisely WHILE the freshly
    // persisted model still has a proposal "in flight" by definition (that
    // proposal having just failed is why they are falling back at all), so
    // this guard would otherwise block its own legitimate fallback attempt.
    final freshModel = payjoin is PayjoinReceiver
        ? await _localPayjoinDatasource.fetchReceiver(payjoin.id)
        : await _localPayjoinDatasource.fetchSender(payjoin.id);
    if (freshModel != null) {
      final freshEntity = freshModel.toEntity();
      if (!freshEntity.canManuallyBroadcastOriginal) {
        log.warning(
          'tryBroadcastOriginalTransaction ignored for ${payjoin.logRef}: '
          'already completed or a proposal is in flight',
        );
        return freshEntity;
      }
    }

    final result = await _broadcastOriginalTransaction(payjoin);
    // Emit on the stream so OTHER live watchers of this same session (e.g. a
    //  transaction-details screen open alongside the receive screen) learn of
    //  the abort without waiting for a reload. Internal callers keep the
    //  "caller emits" contract and add the result themselves; only this
    //  public, UI-triggered entry point has no caller downstream to do it.
    if (result != null) {
      _payjoinStreamController.add(result);
    }
    return result;
  });

  @override
  Future<void> disableReceivers() async {
    final receivers = await _localPayjoinDatasource.fetchReceivers();
    Object? firstError;
    StackTrace? firstStackTrace;
    for (final receiver in receivers) {
      try {
        await _withSessionLock(receiver.id, () async {
          final fresh = await _localPayjoinDatasource.fetchReceiver(
            receiver.id,
          );
          if (fresh == null || fresh.isCompleted || fresh.isAborted) return;
          await _settleReceiverAfterDisable(fresh);
        });
      } catch (e, st) {
        firstError ??= e;
        firstStackTrace ??= st;
        log.severe(
          message:
              'Failed to settle disabled receiver ${receiver.toEntity().logRef}',
          error: e,
          trace: st,
        );
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }

  Future<PayjoinReceiver?> _settleReceiverAfterDisable(
    PayjoinReceiverModel receiver,
  ) async {
    if (receiver.proposalPsbt != null) {
      _watchCommittedReceiver(receiver);
      return receiver.toEntity() as PayjoinReceiver;
    }

    if (receiver.originalTxBytes != null) {
      var declined = receiver;
      try {
        declined = receiver.copyWith(
          receiver: _pdkPayjoinDatasource.declineReceiverSession(receiver),
        );
        final recorded = await _localPayjoinDatasource.recordReceiverRequest(
          declined,
        );
        if (!recorded) return null;
      } on StateError catch (e) {
        // A previous attempt may already have advanced the PDK typestate.
        // Broadcasting the persisted original remains the safe recovery.
        log.warning('Receiver decline already applied: $e');
      }

      final result = await _broadcastOriginalWithRetry(declined.toEntity());
      if (result == null) {
        throw StateError('Failed to settle an active Payjoin receiver');
      }
      return result as PayjoinReceiver;
    }

    _stopWatching(receiver.id);
    await _localPayjoinDatasource.deleteIdleReceiver(receiver.id);
    return null;
  }

  void _watchCommittedReceiver(PayjoinReceiverModel receiver) {
    if (receiver.txId != null) {
      _watchForBroadcast(
        payjoinId: receiver.id,
        walletId: receiver.walletId,
        txId: receiver.txId!,
      );
    }
    if (receiver.originalTxId != null) {
      _watchForFallback(
        payjoinId: receiver.id,
        walletId: receiver.walletId,
        originalTxId: receiver.originalTxId!,
      );
    }
  }

  /// The actual original-transaction broadcast mechanism, shared by the
  /// public (guarded) [tryBroadcastOriginalTransaction] entry point and this
  /// repository's own internal fallback call sites, which intentionally
  /// bypass that guard (see its doc comment for why).
  Future<Payjoin?> _broadcastOriginalTransaction(Payjoin payjoin) async {
    try {
      final network = ElectrumServerNetwork.fromEnvironment(
        isTestnet: payjoin.isTestnet,
        isLiquid: false,
      );

      PayjoinModel? model;
      if (payjoin is PayjoinReceiver) {
        await _serversPort.runWithFallback<void>(
          network: network,
          operation: (connection) => _blockchain.broadcastTransaction(
            payjoin.originalTxBytes!,
            connection: connection,
          ),
        );

        model = await _localPayjoinDatasource.fetchReceiver(payjoin.id);
      } else {
        payjoin as PayjoinSender;
        await _serversPort.runWithFallback<void>(
          network: network,
          operation: (connection) => _blockchain.broadcastPsbt(
            payjoin.originalPsbt,
            connection: connection,
          ),
        );
        model = await _localPayjoinDatasource.fetchSender(payjoin.id);
      }
      // logRef, never id/raw txid: a sender payjoin id is the full BIP21
      // URI and a raw txid identifies the payment on-chain — both off-limits
      // in logs (user-shareable / pasted into issues).
      log.info(
        'Original transaction broadcasted for payjoin ${payjoin.logRef}',
      );

      if (model == null) {
        throw Exception('Payjoin not found locally');
      }
      // This is a fallback broadcast, not a real payjoin: mark the session
      // aborted (not completed) so the true outcome survives in the
      // transaction history — see PayjoinStatus.aborted.
      //
      // txId is explicitly reset: this session is completed by the ORIGINAL
      // transaction, so any txId persisted earlier refers to a payjoin
      // transaction that never reached the chain. A sender's txId is set the
      // moment a proposal is RECEIVED (before signing/broadcasting), so a
      // proposal that later fails to sign/broadcast would otherwise leave a
      // stale txId behind — and SendCubit prefers txId over originalTxId for
      // the success screen and the final tx label, surfacing (and labelling)
      // a txid that was never broadcast. This clearing is display hygiene,
      // not status derivation: the status comes from the explicit isAborted
      // flag (see PayjoinModel.status).
      final abortedModel = model.copyWith(
        isExpired: false,
        isAborted: true,
        txId: null,
      );
      final applied = await _localPayjoinDatasource.markAborted(abortedModel);
      final resolvedModel = applied
          ? abortedModel
          : payjoin is PayjoinReceiver
          ? await _localPayjoinDatasource.fetchReceiver(payjoin.id)
          : await _localPayjoinDatasource.fetchSender(payjoin.id);
      if (resolvedModel == null) {
        throw Exception('Payjoin disappeared while recording fallback');
      }
      if (!resolvedModel.isAborted) return resolvedModel.toEntity();
      // Deliberately NOT labelling this transaction "payjoin": every call
      // site of this method is, by definition, a case where no real payjoin
      // ever happened — declined below the anti-probing minimum, the
      // negotiation failed, or the session expired before a proposal was
      // exchanged. The tx that lands here is byte-for-byte the caller's own
      // plain, single-party transaction; slapping a "payjoin" label on it
      // would be misleading. Only _onPayjoinTransactionSeen and _broadcastPsbt
      // label a transaction — both reachable exclusively once a real proposal
      // was exchanged.
      //
      // Stop watching now that the session is resolved via this path: the
      //  fallback watch armed at request-received (receiver) or session
      //  creation (sender) would otherwise keep doing a wallet-transaction
      //  lookup on every sync for the rest of the app's lifetime. Defensive
      //  and idempotent — a no-op when no watcher is registered. (Re-armed
      //  just below to confirm the tx we broadcast actually lands locally.)
      _stopWatching(payjoin.id);

      // Best-effort, non-blocking: get the wallet's balance/tx list to
      // reflect this broadcast promptly instead of waiting on whatever
      // unrelated sync happens to run next (the same staleness class of gap
      // as the receiver's own payjoin-tx watcher — see _watchForBroadcast).
      _syncWalletAfterBroadcast(resolvedModel.walletId);

      // That single sync is not enough on its own: it can be throttled by
      // the sync coordinator or race the broadcast (observed live: a
      // receiver's below-minimum fallback stayed invisible in its own
      // wallet until several manual resyncs). Re-arm the original-tx watch
      // so its backoff poll keeps forcing DIRECT electrum-backed lookups
      // (getWalletTransaction(sync: true) bypasses the coordinator) until
      // the transaction we just broadcast actually lands in the local
      // wallet database. It tears itself down the moment the tx is seen:
      // _onOriginalTransactionSeen stops all watchers first and its
      // terminal guard makes it a pure teardown for this already-persisted
      // session.
      if (resolvedModel.originalTxId != null) {
        _watchForFallback(
          payjoinId: payjoin.id,
          walletId: resolvedModel.walletId,
          originalTxId: resolvedModel.originalTxId!,
        );
      }

      return resolvedModel.toEntity();
    } catch (e) {
      log.severe(
        message: 'Error broadcasting original transaction',
        error: e,
        trace: StackTrace.current,
      );
      return null;
    }
  }

  Future<void> _processPayjoinRequest(PayjoinReceiverModel model) =>
      _withSessionLock(model.id, () => _processPayjoinRequestInner(model));

  Future<void> _processPayjoinRequestInner(PayjoinReceiverModel model) async {
    // The whole handler is inside this try/catch, including the initial DB
    // update and stream emit below: a fallible await left outside a try (as
    // this used to be) can throw straight out of the datasource's
    // stream .listen() callback as an unhandled async error — with the
    // directory poll already cancelled by the time this fires, no expiry
    // event would ever arrive to unstick it either, stranding the session
    // in "requested" until the app restarts.
    PayjoinReceiver? result;
    try {
      log.info('Processing payjoin request: ${model.id}');
      final recorded = await _localPayjoinDatasource.recordReceiverRequest(
        model,
      );
      if (!recorded) return;

      final payjoin = model.toEntity() as PayjoinReceiver;

      // Notify higher layers that a new payjoin request was received
      _payjoinStreamController.add(payjoin);

      // Arm the fallback safety net now that originalTxId is known: from
      // here on, EITHER side could end up broadcasting the original
      // transaction (this receiver declining below-minimum in a moment, a
      // failed negotiation, or either session's own expiry), and this is
      // the only way this side finds out if it was the OTHER one that did
      // it (see _watchForFallback's doc comment). Left running until the
      // session actually resolves, including through the negotiation
      // attempted below.
      if (model.originalTxId != null) {
        _watchForFallback(
          payjoinId: model.id,
          walletId: model.walletId,
          originalTxId: model.originalTxId!,
        );
      }

      // Anti-probing minimum-value policy (BIP78): declining below this
      // threshold costs the sender nothing extra (they're still paid
      // normally via the original transaction) while raising the cost of
      // probing our UTXO set to at least a real payment above the
      // threshold. See PayjoinConstants.defaultMinAmountSat.
      final settings = await _settingsRepository.fetch();
      if (!settings.isPayjoinEnabled) {
        log.warning(
          'Payjoin request ${model.id} arrived after Payjoin was disabled; '
          'broadcasting the original transaction instead',
        );
        result = await _settleReceiverAfterDisable(model);
      } else if (isBelowPayjoinMinimum(
        amountSat: model.amountSat,
        minAmountSat: settings.payjoinMinAmountSat,
      )) {
        log.warning(
          'Payjoin request ${model.id} below minimum '
          '(${settings.payjoinMinAmountSat} sat); declining and '
          'broadcasting original instead',
        );
        result = await _settleReceiverAfterDisable(model);
      } else {
        final wallet = await _loadWallet(model.walletId);
        final unspentUtxos = await _bdkWallet.getUtxos(wallet: wallet);
        result = await _proposePayjoin(model, wallet, unspentUtxos);
      }
    } catch (e) {
      log.severe(
        message: 'Error processing payjoin request',
        error: e,
        trace: StackTrace.current,
      );
      result =
          (await _broadcastOriginalWithRetry(model.toEntity()))
              as PayjoinReceiver?;
    }

    if (result != null) {
      _payjoinStreamController.add(result);
      // A proposal was sent: from here the sender finalizes and broadcasts
      // the payjoin transaction. Watch for that txid to land on-chain so we
      // can mark the receiver session completed and label the transaction.
      if (result.proposalPsbt != null && result.txId != null) {
        _watchForBroadcast(
          payjoinId: result.id,
          walletId: result.walletId,
          txId: result.txId!,
        );
      }
    }
  }

  /// [_broadcastOriginalTransaction] with a small bounded retry, for the
  /// automatic fallback paths (below-minimum decline and request-processing
  /// failure). Those paths run exactly once per request event: the
  /// directory poll was already cancelled when the request was emitted, so
  /// no expiry event will fire either — a single transient Electrum blip
  /// would otherwise leave the session with no further automatic attempt
  /// this run. If every attempt fails, this logs SEVERE and returns null
  /// ON PURPOSE without marking the session terminal: it stays unfinished
  /// in the DB, so the next app start replays it through
  /// _processPayjoinRequest and retries (the decline path then throws
  /// StateError on the already-cancelled PDK session, which lands in the
  /// same catch → broadcast fallback). In the meantime the receive screen's
  /// manual "receive payment normally" button remains available and
  /// surfaces its own errors.
  ///
  /// Uses [_broadcastOriginalTransaction] directly (not the guarded public
  /// entry point): this is an internal fallback that runs precisely while
  /// the persisted model still has a proposal "in flight", which the guard
  /// would otherwise refuse.
  Future<Payjoin?> _broadcastOriginalWithRetry(
    Payjoin payjoin, {
    int maxAttempts = 3,
    Duration? delayBetweenAttempts,
  }) async {
    final delay = delayBetweenAttempts ?? fallbackRetryDelay;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final result = await _broadcastOriginalTransaction(payjoin);
      if (result != null) return result;
      if (attempt < maxAttempts) {
        await Future<void>.delayed(delay);
      }
    }
    // Each failed attempt already logged SEVERE (with the underlying error)
    // inside _broadcastOriginalTransaction — this is the summary line.
    // logRef, never id: this accepts any Payjoin and a sender id is the full
    //  BIP21 URI.
    log.warning(
      'Failed to broadcast the original transaction after $maxAttempts '
      'attempts; leaving payjoin ${payjoin.logRef} unfinished so the next app '
      'start retries',
    );
    return null;
  }

  /// Whether an incoming payjoin request should be declined for being below
  /// the configured minimum-receive-amount threshold (anti-probing,
  /// BIP78). `null` (no amount known yet) never counts as below minimum —
  /// this only gates once the original transaction has actually been
  /// retrieved and its amount computed (see PdkPayjoinDatasource's receiver
  /// poll), never blocking on an incomplete read.
  @visibleForTesting
  static bool isBelowPayjoinMinimum({
    required int? amountSat,
    required int minAmountSat,
  }) => amountSat != null && amountSat < minAmountSat;

  Future<void> _processPayjoinProposal(PayjoinSenderModel payjoinModel) =>
      _withSessionLock(payjoinModel.id, () async {
        // Same hardening as _processPayjoinRequest: this runs as a bare stream
        // .listen() callback, so any await throwing outside a try (the re-fetch
        // and update below, or the terminal-persist tail) would surface as an
        // unhandled zone error — and with the sender poll already cancelled by
        // the time this fires, nothing else would ever emit a terminal event,
        // stranding the session until the app restarts.
        try {
          await _processPayjoinProposalInner(payjoinModel);
        } catch (e) {
          log.severe(
            message: 'Error processing payjoin proposal event',
            error: e,
            trace: StackTrace.current,
          );
        }
      });

  Future<void> _processPayjoinProposalInner(
    PayjoinSenderModel payjoinModel,
  ) async {
    // The proposal event carries the datasource's own in-memory copy, which
    // may have resolved since (e.g. the fallback watcher aborted the session
    // when the counterparty broadcast the original while this proposal was in
    // flight). Re-fetch and bail on an already-terminal session — mirroring
    // _processExpiredPayjoin — so we neither act on an aborted row nor
    // sign/broadcast against a session that already resolved another way.
    final persisted = await _localPayjoinDatasource.fetchSender(
      payjoinModel.id,
    );
    if (persisted != null && (persisted.isCompleted || persisted.isAborted)) {
      return;
    }

    // Update the local database with the new payjoin proposal
    final recorded = await _localPayjoinDatasource.recordSenderProposal(
      payjoinModel,
    );
    if (!recorded) return;

    final payjoin = payjoinModel.toEntity() as PayjoinSender;

    _payjoinStreamController.add(payjoin);

    PayjoinSender? result;
    String? finalizedPsbt;
    try {
      final wallet = await _loadWallet(payjoin.walletId);
      finalizedPsbt = await _bdkWallet.signPsbt(
        payjoin.proposalPsbt!,
        wallet: wallet,
      );
      result = await _broadcastPsbt(
        payjoinModel: payjoinModel,
        finalizedPsbt: finalizedPsbt,
        network: payjoinModel.isTestnet
            ? Network.bitcoinTestnet
            : Network.bitcoinMainnet,
      );
      // logRef, never id/raw txid: a sender payjoin id is the full BIP21 URI
      //  and a raw txid identifies the payment on-chain — both off-limits in
      //  logs.
      log.info('Payjoin proposal broadcasted for ${payjoin.logRef}');
    } catch (e) {
      log.severe(
        message: 'Error broadcasting payjoin proposal',
        error: e,
        trace: StackTrace.current,
      );
      // Signing or broadcasting the finalized payjoin transaction failed. By
      //  this point the sender's poll timer that would otherwise raise an
      //  expiry is already cancelled (it stopped the moment this proposal
      //  arrived), so nothing else will ever emit a terminal event for this
      //  session — fall back to broadcasting the original transaction
      //  ourselves, mirroring the sender-expiry fallback, so the payment
      //  still goes through and the send flow doesn't hang forever (#2246).
      result = await _broadcastOriginalTransaction(payjoin) as PayjoinSender?;
    }

    if (result != null) {
      _payjoinStreamController.add(result);
      if (result.isCompleted && finalizedPsbt != null) {
        // The payment is already on the network. Txid derivation and labeling
        // are local best-effort work and must never route into the competing
        // original-transaction fallback if either fails.
        try {
          final broadcastTxId = (await BitcoinTx.fromPsbt(finalizedPsbt)).txid;
          await labelCompletedPayjoinSend(broadcastTxId);
        } catch (e, st) {
          log.warning(
            'Payjoin broadcast succeeded but labeling failed',
            error: e,
            trace: st,
          );
        }
      }
    } else {
      // Both the payjoin and the original-transaction fallback failed: mark
      //  the session terminally failed (modelled as expired, which
      //  SendCubit._watchPayjoin already surfaces as a broadcast failure)
      //  instead of leaving the send flow hanging on "coordinating" with no
      //  event ever arriving again. Clear txId: the pre-existing value is a
      //  proposal-derived payjoin txid that never reached the chain, and a
      //  stale txid on a terminal session pollutes fetchByTxId / the details
      //  screen (same display-hygiene reason _broadcastOriginalTransaction
      //  clears it on the abort path).
      //
      // Re-fetch and bail on terminal first: the sign/broadcast attempt
      //  above took a real network round-trip, during which the fallback
      //  watcher could have marked this same session aborted (the original
      //  landing on-chain is exactly what makes the payjoin broadcast fail
      //  on already-spent inputs, and the original re-broadcast fail as
      //  already-known). Persisting from the stale `payjoinModel` here would
      //  overwrite that correct `aborted` outcome with `expired`.
      // Either broadcast may actually have reached the network before its
      // client observed an error. Keep both known txids under observation so
      // the persisted row can still converge instead of repeating failed
      // broadcasts on every startup.
      if (payjoinModel.txId != null) {
        _watchForBroadcast(
          payjoinId: payjoinModel.id,
          walletId: payjoinModel.walletId,
          txId: payjoinModel.txId!,
        );
      }
      _watchForFallback(
        payjoinId: payjoinModel.id,
        walletId: payjoinModel.walletId,
        originalTxId: payjoinModel.originalTxId,
      );

      final freshModel = await _localPayjoinDatasource.fetchSender(
        payjoinModel.id,
      );
      if (freshModel != null &&
          (freshModel.isCompleted || freshModel.isAborted)) {
        return;
      }
      final failedModel = (freshModel ?? payjoinModel).copyWith(
        isExpired: true,
        txId: null,
      );
      final recorded = await _localPayjoinDatasource.markExpired(
        failedModel,
        clearTxId: true,
      );
      if (recorded) _payjoinStreamController.add(failedModel.toEntity());
    }
  }

  Future<void> _processExpiredPayjoin(PayjoinModel payjoinModel) =>
      _withSessionLock(payjoinModel.id, () async {
        // Same hardening as _processPayjoinRequest/_processPayjoinProposal: a
        // bare stream .listen() callback — a DB throw here must be logged, not
        // escape as an unhandled zone error that strands the session.
        try {
          await _processExpiredPayjoinInner(payjoinModel);
        } catch (e) {
          log.severe(
            message: 'Error processing expired payjoin event',
            error: e,
            trace: StackTrace.current,
          );
        }
      });

  Future<void> _processExpiredPayjoinInner(PayjoinModel payjoinModel) async {
    // The expiry event carries the emitter's own in-memory copy of the
    // session (the PDK poll's model from when polling started, or a resume's
    // fetch) — not the persisted row, which may have resolved in the
    // meantime through a path the emitter can't see (the fallback watcher
    // marking it aborted/completed when a transaction landed on-chain).
    // Re-fetch and bail on an already-terminal session: without this, an
    // expiry firing after a fallback completion re-broadcast the original
    // transaction and re-emitted terminal events for a resolved session
    // (observed live: a sender's poll expired a minute after
    // _onOriginalTransactionSeen had already completed the session).
    final freshModel = payjoinModel is PayjoinReceiverModel
        ? await _localPayjoinDatasource.fetchReceiver(payjoinModel.id)
        : await _localPayjoinDatasource.fetchSender(payjoinModel.id);
    if (freshModel == null || freshModel.isCompleted || freshModel.isAborted) {
      return;
    }

    // Continue with the fresh row (expired-marked, like every caller marks
    // its own copy), not the event's copy: the branches below decide on
    // proposalPsbt/originalTxBytes. Persistence below is a conditional partial
    // update, so it cannot clobber fields changed by another transition.
    final expiredModel = freshModel.copyWith(isExpired: true);
    final payjoin = expiredModel.toEntity();

    // TODO: Unfreeze the utxo used in the payjoin

    if (expiredModel is PayjoinReceiverModel &&
        expiredModel.originalTxBytes == null) {
      // No sender ever contacted this endpoint. It is not a transaction and
      // must not leave a terminal 0-sat row in history. Notify the live
      // receive flow so it can rotate to a fresh endpoint, then remove it.
      _stopWatching(expiredModel.id);
      final deleted = await _localPayjoinDatasource.deleteIdleReceiver(
        expiredModel.id,
      );
      if (deleted) _payjoinStreamController.add(payjoin);
      return;
    }

    if (payjoin is PayjoinReceiver &&
        payjoin.originalTxBytes != null &&
        payjoin.proposalPsbt == null) {
      // We received the sender's original transaction but never sent a
      //  proposal before expiring, so broadcast that original automatically —
      //  the receiver still gets paid, and (per BIP78) doing so imposes the
      //  mining-fee cost that makes UTXO probing non-free.
      // Guard on proposalPsbt == null: once a proposal has gone out, the
      //  sender owns finalizing/broadcasting the payjoin transaction, which
      //  spends the same inputs. Broadcasting the original here would just
      //  race our own in-flight payjoin for no benefit.
      //
      //  Emit only the terminal outcome — mirroring the sender-expiry
      //  fallback below — so a receive screen watching this session doesn't
      //  see an interim "expired" state that suggests the original still
      //  needs manual broadcasting when it's actually already in flight.
      //
      //  Deliberately do NOT call _stopWatching before attempting the
      //  broadcast: the fallback watch armed in _processPayjoinRequest must
      //  survive a failed attempt here so it keeps watching for the original
      //  transaction to land through ANY path — a later resume's retry, or
      //  the sender broadcasting it independently in the meantime.
      //  _broadcastOriginalTransaction already stops it on success; leaving
      //  it running on failure is what fixes a session getting permanently
      //  stuck otherwise (observed live).
      //
      //  Deliberately do NOT persist the raw expired model first:
      //  _broadcastOriginalTransaction persists isAborted itself on success.
      //  If the broadcast fails, leaving the row unfinished means the next
      //  app start's resumePayjoinsOnStartup sees isExpiryTimePassed still
      //  true and retries the fallback — persisting isExpired here would
      //  instead permanently exclude it from onlyUnfinished and drop the
      //  retry.
      final result = await _broadcastOriginalTransaction(payjoin);
      _payjoinStreamController.add(result ?? payjoin);
    } else if (payjoin is PayjoinSender && payjoin.proposalPsbt == null) {
      // The sender never received a proposal before expiry (the receiver
      //  didn't respond), so fall back to broadcasting the original
      //  transaction — the payment must still go through. Guard on
      //  proposalPsbt == null: once a proposal arrived, _processPayjoinProposal
      //  owns finalizing/broadcasting the payjoin transaction (same inputs).
      //
      //  Emit only the terminal outcome: the aborted result on success (so
      //  the send flow resolves to success), or the raw expired entity if the
      //  fallback broadcast itself failed (so listeners see a terminal state
      //  and don't hang on the "coordinating" screen). We deliberately do NOT
      //  emit the interim expired entity before the fallback, which would race
      //  the aborted one on the stream.
      //
      //  Same reasoning as the receiver branch above for not persisting the
      //  expired flag up front, and for NOT calling _stopWatching before
      //  attempting: the fallback watch armed at session creation must
      //  survive a failed attempt here.
      final result = await _broadcastOriginalTransaction(payjoin);
      _payjoinStreamController.add(result ?? payjoin);
    } else {
      // A receiver whose proposal was already sent (proposalPsbt != null)
      //  lands here. From here the sender owns finalizing/broadcasting the
      //  payjoin transaction, which can still land on-chain after this
      //  session's own expiry — deliberately do NOT stop the broadcast
      //  watcher armed for it (_watchForBroadcast): once the tx is seen,
      //  _onPayjoinTransactionSeen completes and labels the session even
      //  though it's presently marked expired. Stopping the watcher here
      //  would strand the session as permanently expired despite the payment
      //  actually completing.
      //
      //  Beyond hardening: re-arm the broadcast watcher idempotently. For a
      //  live expiry this is a no-op (the containsKey guard — the watcher
      //  armed at proposal time is still registered); for a resume-time
      //  expiry (app was closed) it re-arms the watcher the session lost
      //  when the app closed, which is exactly the behavior the retention
      //  above intends.
      if (expiredModel is PayjoinReceiverModel && expiredModel.txId != null) {
        _watchForBroadcast(
          payjoinId: expiredModel.id,
          walletId: expiredModel.walletId,
          txId: expiredModel.txId!,
        );
        // Same reasoning as _resumeOne's equivalent receiver branch: the
        //  sender could independently fall back to the original transaction
        //  instead of finalizing the real payjoin, and this receiver would
        //  otherwise have no way to find out — it only watches the payjoin
        //  txid above. Without this, a receiver resumed here stays marked
        //  expired forever despite having actually been paid via the
        //  sender's fallback.
        if (expiredModel.originalTxId != null) {
          _watchForFallback(
            payjoinId: expiredModel.id,
            walletId: expiredModel.walletId,
            originalTxId: expiredModel.originalTxId!,
          );
        }
      }

      // Nothing left for us to retry from this side, so persist the expired
      //  marker now (unlike the two fallback branches above).
      final recorded = await _localPayjoinDatasource.markExpired(expiredModel);
      if (recorded) _payjoinStreamController.add(payjoin);
    }
  }

  @override
  Future<void> resumePayjoinsOnStartup() => _resumeLock.synchronized(() async {
    // Cold-start recovery and an immediate foreground lifecycle callback can
    // overlap. Serialize complete sweeps so the second one reads fresh rows
    // rather than processing snapshots captured before the first converged.
    try {
      await _resumePayjoinsOnStartupUnguarded();
    } catch (e, st) {
      log.severe(
        message: 'Failed to resume payjoin sessions on startup',
        error: e,
        trace: st,
      );
    }
  });

  Future<void> _resumePayjoinsOnStartupUnguarded() async {
    final settings = await _settingsRepository.fetch();
    // Sweep receivers whose expiry-time fallback broadcast FAILED on a
    // previous run and were persisted as expired (e.g. by pre-port code that
    // persisted isExpired before broadcasting): the onlyUnfinished resume
    // below can never see them again while they still hold the sender's
    // broadcastable original transaction. Without this sweep the sender's
    // payment would be stranded forever. One attempt per app start per
    // session: success marks it aborted (ending the retries); a transient
    // failure — or the tx already being on-chain, which the broadcast
    // surfaces as an error — retries on the next start. Uses the internal
    // broadcast (bypassing the manual-call guard): this is an automatic
    // recovery retry, not a manual action.
    final receivers = await _localPayjoinDatasource.fetchReceivers();
    for (final receiver in receivers) {
      if (receiver.isCompleted || receiver.isAborted) continue;
      try {
        await _withSessionLock(receiver.id, () async {
          final fresh = await _localPayjoinDatasource.fetchReceiver(
            receiver.id,
          );
          if (fresh == null || fresh.isCompleted || fresh.isAborted) return;
          if (!settings.isPayjoinEnabled) {
            await _settleReceiverAfterDisable(fresh);
            return;
          }
          if (!fresh.isExpired) return;
          if (fresh.proposalPsbt != null) {
            _watchCommittedReceiver(fresh);
            return;
          }
          if (fresh.originalTxBytes == null) {
            _stopWatching(fresh.id);
            await _localPayjoinDatasource.deleteIdleReceiver(fresh.id);
            return;
          }

          await _broadcastOriginalTransaction(fresh.toEntity());
          // A broadcast error can mean the other side already put this same
          // transaction on-chain. Keep watching so the row converges instead
          // of logging the same failed retry on every startup.
          if (fresh.originalTxId != null) {
            _watchForFallback(
              payjoinId: fresh.id,
              walletId: fresh.walletId,
              originalTxId: fresh.originalTxId!,
            );
          }
        });
      } catch (e, st) {
        log.severe(
          message:
              'Failed to resume payjoin receiver ${receiver.toEntity().logRef}',
          error: e,
          trace: st,
        );
      }
    }

    // Same sweep for senders: a sender's original transaction (originalPsbt)
    // is always available from session creation, unlike a receiver's (which
    // only arrives with the request), so the only guard needed here is
    // proposalPsbt == null — mirroring the receiver branch above.
    final senders = await _localPayjoinDatasource.fetchSenders();
    for (final sender in senders) {
      if (!sender.isExpired || sender.isAborted || sender.isCompleted) continue;
      try {
        if (sender.proposalPsbt != null) {
          if (sender.txId != null) {
            _watchForBroadcast(
              payjoinId: sender.id,
              walletId: sender.walletId,
              txId: sender.txId!,
            );
          }
          _watchForFallback(
            payjoinId: sender.id,
            walletId: sender.walletId,
            originalTxId: sender.originalTxId,
          );
          await _processPayjoinProposal(sender);
          continue;
        }

        PayjoinSenderModel? proposalReceived;
        await _withSessionLock(sender.id, () async {
          final fresh = await _localPayjoinDatasource.fetchSender(sender.id);
          if (fresh == null || fresh.isCompleted || fresh.isAborted) return;
          if (fresh.proposalPsbt != null) {
            proposalReceived = fresh;
            return;
          }
          await _broadcastOriginalTransaction(fresh.toEntity());
          _watchForFallback(
            payjoinId: fresh.id,
            walletId: fresh.walletId,
            originalTxId: fresh.originalTxId,
          );
        });
        if (proposalReceived != null) {
          await _processPayjoinProposal(proposalReceived!);
        }
      } catch (e, st) {
        log.severe(
          message:
              'Failed to resume payjoin sender ${sender.toEntity().logRef}',
          error: e,
          trace: st,
        );
      }
    }

    final models = await _localPayjoinDatasource.fetchAll(onlyUnfinished: true);
    for (final model in models) {
      if (!settings.isPayjoinEnabled && model is PayjoinReceiverModel) {
        continue;
      }
      // Each session is independent: a bug or a transient failure resuming
      //  one (e.g. a missing wallet, a bad persisted event log) must not
      //  abort the loop and silently leave every other unfinished session
      //  un-resumed.
      try {
        await _resumeOne(model);
      } catch (e, st) {
        // logRef, never id: this SEVERE reaches Sentry, and a sender id is
        // the full BIP21 URI.
        log.severe(
          message:
              'Failed to resume payjoin session ${model.toEntity().logRef}',
          error: e,
          trace: st,
        );
      }
    }
  }

  Future<void> _resumeOne(PayjoinModel model) async {
    if (model.isExpiryTimePassed) {
      // A session whose expiry elapsed while the app was closed. Route it
      //  through the same handler as a live expiry so the receiver's
      //  original-transaction fallback still fires — otherwise an
      //  expired-while-closed receiver that already had the sender's
      //  original tx would silently drop it, leaving the sender's payment
      //  in limbo (neither payjoin nor fallback ever hits the chain).
      await _processExpiredPayjoin(model.copyWith(isExpired: true));
    } else if (model is PayjoinReceiverModel) {
      if (model.originalTxBytes == null) {
        // If the original tx bytes are not present, it means the receiver
        //  needs to listen for a payjoin request from the sender.
        _pdkPayjoinDatasource.startListeningForRequest(model);
      } else if (model.proposalPsbt == null) {
        // If the original tx bytes are present but the proposal psbt is not,
        //  it means the receiver has already received a payjoin request and
        //  it should be processed.
        await _processPayjoinRequest(model);
      } else if (model.txId != null) {
        // A proposal was already sent before the app closed. Resume watching
        //  for the payjoin transaction to appear on-chain so the session can
        //  be completed and its transaction labelled.
        _watchForBroadcast(
          payjoinId: model.id,
          walletId: model.walletId,
          txId: model.txId!,
        );
        // The sender still owns finalizing/broadcasting the real proposal
        //  from here, but could instead fall back to the original
        //  transaction on ITS side without this receiver ever being told —
        //  resume the same safety net armed when the request first arrived
        //  (see _watchForFallback's doc comment).
        if (model.originalTxId != null) {
          _watchForFallback(
            payjoinId: model.id,
            walletId: model.walletId,
            originalTxId: model.originalTxId!,
          );
        }
      }
    } else if (model is PayjoinSenderModel) {
      // Resume the fallback safety net regardless of which branch below is
      //  taken: originalTxId is always known for a sender (set at creation),
      //  and the receiver could have broadcast it independently at any point
      //  while the app was closed (see _watchForFallback's doc comment).
      _watchForFallback(
        payjoinId: model.id,
        walletId: model.walletId,
        originalTxId: model.originalTxId,
      );
      if (model.proposalPsbt == null) {
        // If the proposal psbt is not present, it means the sender needs to
        //  listen for a payjoin proposal from the receiver.
        _pdkPayjoinDatasource.startListeningForProposal(model);
      } else {
        // If the proposal psbt is present, it means a payjoin proposal was
        //  already received  and it should be processed.
        await _processPayjoinProposal(model);
      }
    }
  }

  Future<PrivateBdkWalletModel> _loadWallet(String walletId) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) throw Exception('Wallet metadata not found');

    final seed =
        await _seed.get(metadata.masterFingerprint) as MnemonicSeedModel;
    final mnemonic = seed.mnemonicWords.join(' ');

    return WalletModel.privateBdk(
          id: walletId,
          scriptType: metadata.scriptType,
          mnemonic: mnemonic,
          passphrase: seed.passphrase,
          isTestnet: metadata.isTestnet,
        )
        as PrivateBdkWalletModel;
  }

  Future<PayjoinReceiver?> _proposePayjoin(
    PayjoinReceiverModel payjoin,
    PrivateBdkWalletModel wallet,
    List<WalletUtxoModel> unspentUtxos,
  ) {
    return _utxoSelectionLock.synchronized(() async {
      final lockedUtxos = await getUtxosFrozenByOngoingPayjoins();
      final inputPairs = _filterAvailableUtxos(
        unspentUtxos,
        lockedUtxos,
        requestedAmountSat: payjoin.amountSat,
      );

      if (inputPairs.isEmpty) {
        throw NoInputsToPayjoinException(
          'No inputs available to create a new payjoin proposal',
        );
      }

      final freshModel = await _localPayjoinDatasource.fetchReceiver(
        payjoin.id,
      );
      if (freshModel == null) throw Exception('Payjoin receiver not found');
      // Re-check terminal state under the lock: a manual "receive payment
      //  normally" tap (allowed by canManuallyBroadcastOriginal while
      //  proposalPsbt == null) or the fallback watcher could have resolved
      //  this session while we were awaiting getUtxosFrozenByOngoingPayjoins
      //  above. Without this, an already-aborted/completed/expired row would
      //  be resurrected to `proposed` by the update below.
      if (freshModel.isCompleted ||
          freshModel.isAborted ||
          freshModel.isExpired) {
        log.warning(
          'Skipping payjoin proposal for ${freshModel.toEntity().logRef}: '
          'session already resolved (${freshModel.status})',
        );
        return null;
      }

      final isMineSync = await _bdkWallet.createIsMineChecker(wallet: wallet);
      final signPsbtSync = await _bdkWallet.createPsbtSigner(wallet: wallet);
      final updatedModel = await _pdkPayjoinDatasource.proposePayjoin(
        receiverModel: freshModel,
        hasOwnedInputs: isMineSync,
        hasReceiverOutput: isMineSync,
        inputPairs: inputPairs,
        processPsbt: signPsbtSync,
      );

      try {
        final recorded = await _localPayjoinDatasource.recordReceiverProposal(
          updatedModel,
        );
        if (!recorded) {
          final resolved = await _localPayjoinDatasource.fetchReceiver(
            payjoin.id,
          );
          if (resolved != null &&
              (resolved.isCompleted || resolved.isAborted)) {
            return null;
          }
          log.severe(
            message:
                'Payjoin proposal was sent but its state was not persisted',
            error: StateError('Receiver proposal transition was rejected'),
            trace: StackTrace.current,
          );
        }
      } catch (e, st) {
        // proposePayjoin posts to the directory before returning. Falling back
        // to the original now would race the sender finalizing that proposal.
        // The selected UTXO is no longer represented by persisted state, so
        // another receiver can select it after this lock releases and restart
        // can attempt this request again. Closing that residual race requires
        // a durable write-ahead proposal reservation before publication; an
        // original-transaction fallback here would be more dangerous.
        log.severe(
          message: 'Payjoin proposal was sent but persistence failed',
          error: e,
          trace: st,
        );
      }
      return updatedModel.toEntity() as PayjoinReceiver;
    });
  }

  /// The candidate set handed to PDK's `tryPreservingPrivacy`, minus the UTXOs
  /// already committed to another live payjoin.
  ///
  /// Confirmed candidates are preferred, because a payjoin spending our
  /// unconfirmed input can be invalidated by an RBF of that input's parent
  /// after both sides consider the payment done. PDK selects on privacy
  /// heuristics alone, so the narrowing must happen here.
  ///
  /// The preference is bounded by [requestedAmountSat]: narrowing only happens
  /// when a confirmed candidate is at least as large as the payment, i.e. the
  /// order of magnitude `avoid_uih` needs to produce a proposal that does not
  /// scream "unnecessary input". Without that floor, a confirmed dust UTXO
  /// would outrank a well-sized unconfirmed one, `avoid_uih` would find no
  /// acceptable selection and `select_first_candidate` would contribute the
  /// dust — payjoin "active" but UIH-revealing, which is the privacy gain it
  /// exists for. When no confirmed candidate clears the floor, the whole set
  /// is handed over and PDK picks: a fresh wallet whose balance is still
  /// unconfirmed keeps payjoining immediately (see
  /// ReceiveBloc._isPayjoinEligible for the accepted residual risk).
  ///
  /// A null [requestedAmountSat] (the amount is read from the original
  /// transaction when the request arrives, so this only happens if a session
  /// somehow reaches here before that) disables the floor and keeps the plain
  /// confirmed-first preference: without an amount there is no mismatch to
  /// detect, while the RBF argument still holds.
  List<PayjoinInputPairModel> _filterAvailableUtxos(
    List<WalletUtxoModel> unspent,
    List<({String txId, int vout})> locked, {
    required int? requestedAmountSat,
  }) {
    final candidates = unspent
        .where((u) => !locked.any((l) => l.txId == u.txId && l.vout == u.vout))
        .whereType<BitcoinWalletUtxoModel>()
        .toList();
    final confirmed = candidates.where((u) => u.confirmations > 0).toList();
    final preferConfirmed = requestedAmountSat == null
        ? confirmed.isNotEmpty
        : confirmed.any((u) => u.amountSat >= BigInt.from(requestedAmountSat));
    return (preferConfirmed ? confirmed : candidates)
        .map((u) => PayjoinInputPairModel.fromWalletUtxoModel(u))
        .toList();
  }

  Future<PayjoinSender> _broadcastPsbt({
    required PayjoinSenderModel payjoinModel,
    required String finalizedPsbt,
    required Network network,
  }) async {
    await _serversPort.runWithFallback<void>(
      network: ElectrumServerNetwork.fromEnvironment(
        isTestnet: network.isTestnet,
        isLiquid: false,
      ),
      operation: (connection) =>
          _blockchain.broadcastPsbt(finalizedPsbt, connection: connection),
    );

    // From this point the real payjoin is on the network. Local persistence,
    // syncing and watcher setup must never throw back to the caller's fallback
    // catch, which would broadcast the competing original transaction.
    var completedModel = payjoinModel.copyWith(
      isExpired: false,
      isCompleted: true,
      isAborted: false,
    );
    try {
      final persisted = await _localPayjoinDatasource.fetchSender(
        payjoinModel.id,
      );
      if (persisted?.isAborted == true) {
        log.warning(
          'Payjoin ${payjoinModel.toEntity().logRef} broadcast after the '
          'original transaction was observed; the network will resolve the '
          'conflict',
        );
      }
      completedModel = (persisted ?? payjoinModel).copyWith(
        isExpired: false,
        isCompleted: true,
        isAborted: false,
      );
      final applied = await _localPayjoinDatasource.markCompleted(
        completedModel,
      );
      if (!applied) {
        final resolved = await _localPayjoinDatasource.fetchSender(
          payjoinModel.id,
        );
        if (resolved?.isCompleted == true) completedModel = resolved!;
      }
    } catch (e, st) {
      log.severe(
        message: 'Payjoin broadcast succeeded but completion was not persisted',
        error: e,
        trace: st,
      );
    }

    // Best-effort, non-blocking: see _broadcastOriginalTransaction's call
    // for why this can't wait on some unrelated sync to run.
    _syncWalletAfterBroadcast(completedModel.walletId);

    // The session is resolved by the payjoin transaction we just broadcast:
    // stop the original-tx fallback watch armed at session creation (it
    // would otherwise keep looking up a transaction that can never land on
    // every sync for the rest of the app's lifetime) and watch the payjoin
    // txid instead until it is visible in the local wallet — the single
    // unawaited sync above can be throttled or race the broadcast (see
    // _broadcastOriginalTransaction). Self-tearing-down like the fallback
    // watch: _onPayjoinTransactionSeen stops all watchers first, and its
    // fetchReceiver returns null for this SENDER session, making it a pure
    // teardown.
    _stopWatching(payjoinModel.id);
    if (completedModel.txId != null) {
      _watchForBroadcast(
        payjoinId: payjoinModel.id,
        walletId: completedModel.walletId,
        txId: completedModel.txId!,
      );
    }

    return completedModel.toEntity() as PayjoinSender;
  }

  /// Delay before the first active broadcast poll of [_watchForBroadcast].
  /// The sender typically finalizes and broadcasts within seconds of
  /// receiving the proposal, so the first forced lookup comes quickly.
  @visibleForTesting
  static const broadcastPollInitialDelay = Duration(seconds: 5);

  /// Cap for the exponential backoff between active broadcast polls.
  @visibleForTesting
  static const broadcastPollMaxDelay = Duration(minutes: 5);

  /// Number of active broadcast polls before giving up on forcing syncs
  /// ourselves (≈35 minutes with the initial delay doubling up to the cap).
  /// The passive sync-driven watcher stays armed afterwards, so a very late
  /// broadcast is still caught by the next organic wallet sync — this bound
  /// only stops a stranded session from forcing network syncs forever.
  @visibleForTesting
  static const broadcastPollMaxAttempts = 12;

  /// Watches for the receiver's payjoin transaction [txId] to appear in
  /// [walletId], then marks the session completed, labels the transaction,
  /// and stops watching. Two complementary triggers:
  ///
  /// - Passive: a cheap local lookup whenever a sync of this wallet finishes
  ///   (the stream re-emits on every sync, so the first successful hit
  ///   cancels the watcher to keep the completion side effect one-shot).
  /// - Active: a bounded backoff of forced `sync: true` lookups. Without it,
  ///   completion depended entirely on some unrelated sync happening to run
  ///   while the session was live — observed live as a receiver stuck on
  ///   "payjoin in progress" for ~9 minutes after the sender had already
  ///   broadcast the payjoin transaction, because nothing else synced the
  ///   wallet in the meantime.
  ///
  /// Idempotent: a session already being watched (live path then resume, or
  /// duplicate resume) is not re-subscribed.
  void _watchForBroadcast({
    required String payjoinId,
    required String walletId,
    required String txId,
  }) => _watchForTransaction(
    payjoinId: payjoinId,
    walletId: walletId,
    txId: txId,
    watchers: _broadcastWatchers,
    pollTimers: _broadcastPollTimers,
    onSeen: (payjoinId) => _onPayjoinTransactionSeen(payjoinId, txId),
    kind: 'broadcast',
  );

  /// Watches for the ORIGINAL transaction [originalTxId] to appear in
  /// [walletId] — the safety net for the plain-broadcast fallback landing
  /// through a path this device didn't itself observe succeed.
  ///
  /// Both a sender and a receiver hold their own copy of the original
  /// transaction and can each independently decide to broadcast it (a
  /// receiver declining below the anti-probing minimum, either side's
  /// session expiring with no proposal exchanged, or a sender's own
  /// negotiation failing). Whichever side attempts the broadcast persists
  /// the terminal state itself on success, but there was previously no way
  /// for the OTHER side to find out — it just kept waiting on its own
  /// session with no signal that the payment had already landed via the
  /// other side's fallback. Observed live: a receiver declining
  /// below-minimum broadcasts the original immediately, while the sender's
  /// own session sat on "requested" for up to a minute until ITS expiry
  /// timer independently fired — and if that second, redundant broadcast
  /// attempt then errored (the tx was already known to the network), the
  /// sender's session never completed at all.
  ///
  /// Armed as soon as `originalTxId` is known — session creation for a
  /// sender, request-received for a receiver — and left running alongside
  /// any later [_watchForBroadcast] for the same session: whichever of the
  /// real payjoin txid or this original txid lands on-chain first resolves
  /// the session, and [_stopWatching] tears down both together. Mirrors
  /// [_watchForBroadcast]'s passive+active polling exactly.
  ///
  /// Idempotent, same as [_watchForBroadcast].
  void _watchForFallback({
    required String payjoinId,
    required String walletId,
    required String originalTxId,
  }) => _watchForTransaction(
    payjoinId: payjoinId,
    walletId: walletId,
    txId: originalTxId,
    watchers: _fallbackWatchers,
    pollTimers: _fallbackPollTimers,
    onSeen: _onOriginalTransactionSeen,
    kind: 'fallback',
  );

  /// Shared engine behind [_watchForBroadcast] and [_watchForFallback]. See
  /// those wrappers for the per-kind rationale; the two registries stay
  /// separate because both watches can be live for one session at once and
  /// [_stopWatching] tears them down together.
  void _watchForTransaction({
    required String payjoinId,
    required String walletId,
    required String txId,
    required Map<String, StreamSubscription<void>> watchers,
    required Map<String, Timer> pollTimers,
    required Future<void> Function(String payjoinId) onSeen,
    required String kind,
  }) {
    if (watchers.containsKey(payjoinId)) return;

    // Best-effort: failing to arm the watch (e.g. a wallet lookup throwing
    // synchronously) must never take down the proposal/broadcast/resume
    // handling it was called from — a successful broadcast misreported as
    // failed would trigger a redundant fallback.
    try {
      final subscription = _walletRepository().walletSyncFinishedStream
          .where((wallet) => wallet.id == walletId)
          .asyncMap((_) async {
            try {
              return await _walletTransactionRepository().getWalletTransaction(
                txId,
                walletId: walletId,
              );
            } catch (e) {
              log.warning('Payjoin $kind watch lookup failed: $e');
              return null;
            }
          })
          .where((tx) => tx != null)
          .listen((_) {
            // onSeen (fetch + update + emit) can throw; the future is not
            //  awaited by the stream, so guard it explicitly or it becomes an
            //  unhandled zone error.
            unawaited(
              onSeen(payjoinId).catchError((Object e) {
                log.warning('Payjoin $kind completion handler failed: $e');
              }),
            );
          });

      watchers[payjoinId] = subscription;

      _scheduleTransactionPoll(
        payjoinId: payjoinId,
        walletId: walletId,
        txId: txId,
        watchers: watchers,
        pollTimers: pollTimers,
        onSeen: onSeen,
        kind: kind,
        attempt: 0,
      );
    } catch (e) {
      // logRefForId: payjoinId is the raw session id, which for a sender IS
      //  the full BIP21 URI (address+amount) — never log it raw.
      log.warning(
        'Failed to arm the $kind watch for '
        '${Payjoin.logRefForId(payjoinId)}: $e',
      );
    }
  }

  /// Arms the next active poll for [_watchForTransaction]: after an
  /// exponentially backed-off delay, forces a sync'd wallet-transaction
  /// lookup and either resolves the session or reschedules itself. The
  /// `watchers` map is the single source of truth for "still watched": once
  /// [_stopWatching] removed the session, a pending poll callback becomes a
  /// no-op.
  void _scheduleTransactionPoll({
    required String payjoinId,
    required String walletId,
    required String txId,
    required Map<String, StreamSubscription<void>> watchers,
    required Map<String, Timer> pollTimers,
    required Future<void> Function(String payjoinId) onSeen,
    required String kind,
    required int attempt,
  }) {
    if (attempt >= broadcastPollMaxAttempts) {
      // The passive sync-driven watcher stays armed; only stop forcing syncs.
      //  Drop the fired timer from the map so it doesn't falsely advertise an
      //  active poll (its cancel() is already a no-op).
      pollTimers.remove(payjoinId);
      return;
    }

    var delay = broadcastPollInitialDelay * (1 << attempt.clamp(0, 30));
    if (delay > broadcastPollMaxDelay) delay = broadcastPollMaxDelay;

    pollTimers[payjoinId] = Timer(delay, () async {
      if (!watchers.containsKey(payjoinId)) return;

      WalletTransaction? tx;
      try {
        tx = await _walletTransactionRepository().getWalletTransaction(
          txId,
          walletId: walletId,
          sync: true,
        );
      } catch (e) {
        log.warning('Payjoin $kind poll failed: $e');
      }

      // Re-check: the session may have resolved through the passive watcher
      // (or been torn down) while the sync'd lookup was in flight.
      if (!watchers.containsKey(payjoinId)) return;

      if (tx != null) {
        // Guarded: this runs inside a Timer callback, so a throw would be an
        //  unhandled zone error (same reasoning as the passive watcher).
        try {
          await onSeen(payjoinId);
        } catch (e) {
          log.warning('Payjoin $kind completion handler failed: $e');
        }
        if (watchers.containsKey(payjoinId)) {
          _scheduleTransactionPoll(
            payjoinId: payjoinId,
            walletId: walletId,
            txId: txId,
            watchers: watchers,
            pollTimers: pollTimers,
            onSeen: onSeen,
            kind: kind,
            attempt: attempt + 1,
          );
        }
      } else {
        _scheduleTransactionPoll(
          payjoinId: payjoinId,
          walletId: walletId,
          txId: txId,
          watchers: watchers,
          pollTimers: pollTimers,
          onSeen: onSeen,
          kind: kind,
          attempt: attempt + 1,
        );
      }
    });
  }

  Future<void> _onPayjoinTransactionSeen(
    String payjoinId,
    String observedTxId,
  ) => _withSessionLock(payjoinId, () async {
    final receiver = await _localPayjoinDatasource.fetchReceiver(payjoinId);
    final PayjoinModel? model =
        receiver ?? await _localPayjoinDatasource.fetchSender(payjoinId);
    if (model == null || model.isCompleted) {
      _stopWatching(payjoinId);
      return;
    }

    final PayjoinModel completedModel = model is PayjoinReceiverModel
        ? model.copyWith(
            txId: model.txId ?? observedTxId,
            isExpired: false,
            isCompleted: true,
            isAborted: false,
          )
        : (model as PayjoinSenderModel).copyWith(
            txId: model.txId ?? observedTxId,
            isExpired: false,
            isCompleted: true,
            isAborted: false,
          );
    final applied = await _localPayjoinDatasource.markCompleted(completedModel);
    if (!applied) {
      final refreshed = model is PayjoinReceiverModel
          ? await _localPayjoinDatasource.fetchReceiver(payjoinId)
          : await _localPayjoinDatasource.fetchSender(payjoinId);
      if (refreshed?.isCompleted == true) _stopWatching(payjoinId);
      return;
    }

    // Persistence won. Any already-delivered duplicate callback now observes
    // the terminal row under the same session lock and becomes a no-op.
    _stopWatching(payjoinId);
    if (completedModel is PayjoinReceiverModel && completedModel.txId != null) {
      await _labelPayjoinTransaction(
        txId: completedModel.txId!,
        walletId: completedModel.walletId,
      );
    }
    _payjoinStreamController.add(completedModel.toEntity());
    log.info(
      'Payjoin ${completedModel.toEntity().logRef} completed on broadcast',
    );
  });

  /// The original transaction landed on-chain — regardless of which side
  /// actually broadcast it (this repository's own attempt, possibly already
  /// failed, or the counterparty's independent fallback) — so this session
  /// is resolved via the plain-broadcast fallback (status `aborted`), never
  /// a real payjoin. `txId` is cleared for the same reason
  /// [_broadcastOriginalTransaction] clears it. Never labels the transaction
  /// "payjoin" — this is by definition not a real one.
  Future<void> _onOriginalTransactionSeen(String payjoinId) => _withSessionLock(
    payjoinId,
    () async {
      final receiverModel = await _localPayjoinDatasource.fetchReceiver(
        payjoinId,
      );
      final PayjoinModel? model =
          receiverModel ?? await _localPayjoinDatasource.fetchSender(payjoinId);
      if (model == null || model.isCompleted || model.isAborted) {
        _stopWatching(payjoinId);
        return;
      }

      final PayjoinModel abortedModel = model is PayjoinReceiverModel
          ? model.copyWith(isExpired: false, isAborted: true, txId: null)
          : (model as PayjoinSenderModel).copyWith(
              isExpired: false,
              isAborted: true,
              txId: null,
            );
      final applied = await _localPayjoinDatasource.markAborted(abortedModel);
      if (!applied) {
        final refreshed = model is PayjoinReceiverModel
            ? await _localPayjoinDatasource.fetchReceiver(payjoinId)
            : await _localPayjoinDatasource.fetchSender(payjoinId);
        if (refreshed?.isCompleted == true || refreshed?.isAborted == true) {
          _stopWatching(payjoinId);
        }
        return;
      }
      _stopWatching(payjoinId);
      _syncWalletAfterBroadcast(abortedModel.walletId);
      final abortedEntity = abortedModel.toEntity();
      _payjoinStreamController.add(abortedEntity);
      log.info(
        'Payjoin ${abortedEntity.logRef} resolved via the original '
        'transaction observed on-chain (fallback, not necessarily broadcast '
        'by this device)',
      );
    },
  );

  /// Stops every watcher of a session — the real-payjoin broadcast watch
  /// ([_watchForBroadcast]), the original-transaction fallback watch
  /// ([_watchForFallback]) AND the PDK directory poll — since the session
  /// resolving through any one of them means there is nothing left to watch
  /// for on the others. Stopping the directory poll matters as much as the
  /// two watchers: a session resolved via the fallback otherwise keeps its
  /// request/proposal poll firing until expiry, which then raises a stale
  /// expired event for an already-completed session (see
  /// [_processExpiredPayjoin]'s guard). Synchronous on purpose:
  /// `StreamSubscription.cancel()` already guarantees no further events are
  /// delivered from the moment it is CALLED, so nothing here needs to block
  /// on its returned future (which only signals resource cleanup) — and
  /// awaiting it would make completion latency depend on the upstream
  /// stream's teardown.
  void _stopWatching(String payjoinId) {
    _broadcastPollTimers.remove(payjoinId)?.cancel();
    final broadcastSubscription = _broadcastWatchers.remove(payjoinId);
    if (broadcastSubscription != null) {
      unawaited(broadcastSubscription.cancel());
    }
    _fallbackPollTimers.remove(payjoinId)?.cancel();
    final fallbackSubscription = _fallbackWatchers.remove(payjoinId);
    if (fallbackSubscription != null) {
      unawaited(fallbackSubscription.cancel());
    }
    _pdkPayjoinDatasource.stopPolling(payjoinId);
  }

  /// Fire-and-forget wallet sync after WE broadcast a transaction (either a
  /// real payjoin proposal or a plain fallback) — the only two places this
  /// repository itself puts a new transaction on the network. Not awaited by
  /// callers: it must never delay resolving the payjoin session (this can
  /// take a real network round-trip), and a transient failure here (no
  /// network at that exact moment) shouldn't be treated as the broadcast —
  /// which already succeeded — having failed. The next organic sync (or the
  /// receiver's own _watchForBroadcast poll) still catches up eventually.
  ///
  /// The call is wrapped in `Future(() => ...)` rather than invoked directly:
  /// this repository's callers (_broadcastOriginalTransaction, _broadcastPsbt)
  /// already wrap their whole body in a try/catch for the broadcast itself,
  /// so a SYNCHRONOUS throw from `_walletRepository()` or `getWallet(...)` (as
  /// opposed to the future it returns rejecting) would otherwise be caught by
  /// that outer try/catch and misreported as the broadcast having failed,
  /// even though it already succeeded.
  void _syncWalletAfterBroadcast(String walletId) {
    unawaited(
      Future(
        () => _walletRepository().getWallet(walletId, sync: true),
      ).catchError((Object e) {
        log.warning('Failed to sync wallet after payjoin broadcast: $e');
        return null;
      }),
    );
  }

  /// Tags a completed payjoin transaction with the payjoin system label so it
  /// is recognisable as a payjoin in the transaction list. Best-effort: a
  /// labelling failure must never fail the (already broadcast) payjoin, so it
  /// is logged and swallowed. Idempotent — the labels store dedupes on
  /// (label, reference).
  Future<void> _labelPayjoinTransaction({
    required String txId,
    required String walletId,
  }) async {
    try {
      final result = await _labelsFacade().store(
        NewLabel.tx(
          transactionId: txId,
          label: LabelSystem.payjoin.label,
          origin: walletId,
        ),
      );
      result.fold(
        (_) {},
        (failure) => log.warning(
          'Failed to label payjoin transaction',
          error: failure.logMessage,
        ),
      );
    } catch (e) {
      log.warning('Failed to label payjoin transaction', error: e);
    }
  }

  /// Best-effort and idempotent, matching the labelling elsewhere in the
  /// codebase that touches this same facade from core (see
  /// LabelExchangeOrdersUsecase, AutoSwapExecutionUsecase): a labelling
  /// failure is logged and swallowed so it never fails the already-broadcast
  /// payjoin, and the labels store dedupes on (label, reference) so a
  /// repeated call for the same txid is harmless.
  ///
  /// Not private (and marked [visibleForTesting]) so it can be exercised
  /// directly: driving it through the full reactive sender pipeline needs a
  /// real, valid PSBT for BitcoinTx.fromPsbt to parse (FFI-backed — the
  /// existing payjoin datasource tests document the same offline-fixture
  /// constraint), which isn't practical to construct in a unit test.
  @visibleForTesting
  Future<void> labelCompletedPayjoinSend(String txId) async {
    try {
      final result = await _labelsFacade().store(
        NewLabel.tx(transactionId: txId, label: LabelSystem.payjoin.label),
      );
      result.fold(
        (_) {},
        (failure) => log.warning(
          'Failed to label completed payjoin send',
          error: failure.logMessage,
        ),
      );
    } catch (e) {
      log.warning('Failed to label completed payjoin send', error: e);
    }
  }
}

class NoInputsToPayjoinException extends BullException {
  NoInputsToPayjoinException(super.message);
}
