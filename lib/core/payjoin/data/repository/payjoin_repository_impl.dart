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
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart';
import 'package:bb_mobile/core/utils/constants.dart' show PayjoinConstants;
import 'package:bb_mobile/core/utils/log_redaction.dart';
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
import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart';

class PayjoinRepositoryImpl implements PayjoinRepository {
  final LocalPayjoinDatasource _localPayjoinDatasource;
  final PdkPayjoinDatasource _pdkPayjoinDatasource;
  final WalletMetadataDatasource _walletMetadataDatasource;
  final SeedDatasource _seed;
  final BdkWalletDatasource _bdkWallet;
  final BdkBitcoinBlockchainDatasource _blockchain;
  final ElectrumServersPort _serversPort;
  // Wallet repositories and the labels facade are resolved lazily (via
  // closures, not injected instances) because this repository is an eager
  // singleton constructed BEFORE WalletLocator / the labels facade register
  // them (see core_locator.dart ordering). They are only ever called well
  // after startup, from broadcast / proposal / completion handlers.
  final WalletRepository Function() _walletRepository;
  final WalletTransactionRepository Function() _walletTransactionRepository;
  // SettingsRepository is registered before payjoin, so it can be injected
  // directly (not as a closure).
  final SettingsRepository _settingsRepository;
  final LabelsFacade Function() _labelsFacade;
  // Lock to prevent the same utxo from being used in multiple payjoin proposals
  final Lock _lock;

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

  // Datasource stream subscriptions, cancelled on dispose.
  final List<StreamSubscription<void>> _datasourceSubscriptions = [];

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
       _lock = Lock(),
       _payjoinStreamController = StreamController<Payjoin>.broadcast() {
    // Listen to payjoin events from the datasource and process them
    _datasourceSubscriptions.addAll([
      _pdkPayjoinDatasource.requestsForReceivers.listen(_processPayjoinRequest),
      _pdkPayjoinDatasource.proposalsForSenders.listen(_processPayjoinProposal),
      _pdkPayjoinDatasource.expiredPayjoins.listen(_processExpiredPayjoin),
    ]);

    // Deliberately NOT resuming here: this is an eager singleton constructed
    //  before WalletLocator / the labels facade register their dependencies
    //  (see core_locator.dart ordering). A resumed session that reaches
    //  _watchForBroadcast or the labels facade before those are registered
    //  would throw inside this unawaited constructor call, silently aborting
    //  resume for every remaining session. resumePayjoinsOnStartup() is
    //  called explicitly by AppLocator.setup once locator setup is fully
    //  done, so every dependency is guaranteed registered by then.
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
    for (final sub in _datasourceSubscriptions) {
      await sub.cancel();
    }
    _datasourceSubscriptions.clear();
    await _pdkPayjoinDatasource.dispose();
    await _payjoinStreamController.close();
  }

  @override
  Stream<Payjoin> get payjoinStream => _payjoinStreamController.stream;

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
    final model = await _pdkPayjoinDatasource.createReceiver(
      walletId: walletId,
      address: address,
      isTestnet: isTestnet,
      maxFeeRateSatPerVb: maxFeeRateSatPerVb,
      expireAfterSec: expireAfterSec,
    );

    // Store the payjoin receiver in the local database
    await _localPayjoinDatasource.storeReceiver(model);

    final payjoin = model.toEntity() as PayjoinReceiver;

    return payjoin;
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
  }) async {
    // Create the payjoin sender session
    final model = await _pdkPayjoinDatasource.createSender(
      walletId: walletId,
      isTestnet: isTestnet,
      bip21: bip21,
      originalPsbt: originalPsbt,
      networkFeesSatPerVb: networkFeesSatPerVb,
      amountSat: amountSat,
      expireAfterSec: expireAfterSec,
    );

    // Store the payjoin sender in the local database
    await _localPayjoinDatasource.storeSender(model);

    // Return a payjoin entity with send details
    final payjoin = model.toEntity();

    return payjoin as PayjoinSender;
  }

  @override
  Future<Payjoin?> tryBroadcastOriginalTransaction(Payjoin payjoin) async {
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

    return _broadcastOriginalTransaction(payjoin);
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
      // logRef + salted token only: a sender payjoin id is the full BIP21
      // URI and a raw txid identifies the payment on-chain — both are
      // off-limits in logs (user-shareable / pasted into issues).
      log.info(
        'Original transaction broadcasted for payjoin ${payjoin.logRef} '
        '(tx ${logSafeToken(payjoin.originalTxId)})',
      );

      // Update the local database with the completed payjoin

      if (model == null) {
        throw Exception('Payjoin not found locally');
      }
      // txId is explicitly reset: this session is completed by the ORIGINAL
      // transaction, so any txId persisted earlier refers to a payjoin
      // transaction that never reached the chain. A sender's txId is set the
      // moment a proposal is RECEIVED (before signing/broadcasting), so a
      // proposal that later fails to sign/broadcast would otherwise leave a
      // stale txId behind — and SendCubit prefers txId over originalTxId for
      // the success screen and the final tx label, surfacing (and labelling)
      // a txid that was never broadcast. This also makes `txId != null` on a
      // completed session a reliable "a real payjoin happened" marker.
      final completedModel = model.copyWith(isCompleted: true, txId: null);
      await _localPayjoinDatasource.update(completedModel);
      // Deliberately NOT labelling this transaction "payjoin": every call
      // site of this method is, by definition, a case where no real payjoin
      // ever happened — declined below the anti-probing minimum, the
      // negotiation failed, or the session expired before a proposal was
      // exchanged. The tx that lands here is byte-for-byte the caller's own
      // plain, single-party transaction; slapping a "payjoin" label on it
      // would be misleading (e.g. to a user filtering their history by that
      // label to see which sends actually got CoinJoin-style privacy). Only
      // _onPayjoinTransactionSeen and _broadcastPsbt label a transaction —
      // both reachable exclusively once a real proposal was exchanged.
      // If this receiver session had a proposal in flight (e.g. the user
      //  broadcast the original manually via "receive payment normally"
      //  while _watchForBroadcast was still armed for it), stop watching now
      //  that the session is completed via this path instead — otherwise the
      //  watcher would keep doing a wallet-transaction lookup on every sync
      //  for the rest of the app's lifetime. A no-op for a sender (or a
      //  receiver with no watcher registered).
      _stopWatching(payjoin.id);

      // Best-effort, non-blocking: get the wallet's balance/tx list to
      // reflect this broadcast promptly instead of waiting on whatever
      // unrelated sync happens to run next (the same staleness class of gap
      // as the receiver's own payjoin-tx watcher — see _watchForBroadcast).
      _syncWalletAfterBroadcast(completedModel.walletId);

      return completedModel.toEntity();
    } catch (e) {
      log.severe(
        message: 'Error broadcasting original transaction',
        error: e,
        trace: StackTrace.current,
      );
      return null;
    }
  }

  Future<void> _processPayjoinRequest(PayjoinReceiverModel model) async {
    log.info('Processing payjoin request: ${model.id}');
    // Update the local database with the new payjoin request
    await _localPayjoinDatasource.update(model);

    final payjoin = model.toEntity() as PayjoinReceiver;

    // Notify higher layers that a new payjoin request was received
    _payjoinStreamController.add(payjoin);

    // Below the configured minimum, don't payjoin at all: just broadcast the
    // sender's original transaction. A small payment isn't worth exposing a
    // decoy UTXO for, and requiring a minimum stake per attempt is a
    // deliberate anti-probing lever (see UTXO probing attack, BIP78). The
    // sender is still paid normally.
    final settings = await _settingsRepository.fetch();
    if (isBelowPayjoinMinimum(
      amountSat: model.amountSat,
      minAmountSat: settings.payjoinMinAmountSat,
    )) {
      // WARNING, not info: this is the anti-probing threshold actively
      // declining a payjoin, worth a developer/operator's attention (and
      // distinct from the routine INFO-level session lifecycle logging
      // around it) even though the sender is still paid normally.
      log.warning(
        'Payjoin request ${model.id} below minimum '
        '(${settings.payjoinMinAmountSat} sat); broadcasting original instead',
      );
      final result =
          (await _broadcastOriginalTransaction(payjoin)) as PayjoinReceiver?;
      if (result != null) _payjoinStreamController.add(result);
      return;
    }

    // Now try to process the request. A transient network failure while
    // posting the proposal to the OHTTP relays (PayjoinNotFoundException) is
    // retried a few times before giving up: the receiver request event fires
    // only once (its poll timer is cancelled on emit), so without an in-place
    // retry a momentary relay blip would fall straight through to the
    // original-transaction fallback and irrevocably cancel the payjoin.
    PayjoinReceiver? result;
    try {
      final wallet = await _loadWallet(model.walletId);
      final unspentUtxos = await _bdkWallet.getUtxos(wallet: wallet);
      result = await retryOnTransient(
        () => _proposePayjoin(model, wallet, unspentUtxos),
      );
    } catch (e) {
      log.severe(
        message: 'Error processing payjoin request',
        error: e,
        trace: StackTrace.current,
      );
      result =
          (await _broadcastOriginalTransaction(payjoin)) as PayjoinReceiver?;
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

  Future<void> _processPayjoinProposal(PayjoinSenderModel payjoinModel) async {
    // Update the local database with the new payjoin proposal
    await _localPayjoinDatasource.update(payjoinModel);

    final payjoin = payjoinModel.toEntity() as PayjoinSender;

    _payjoinStreamController.add(payjoin);

    PayjoinSender? result;
    try {
      final wallet = await _loadWallet(payjoin.walletId);
      final finalizedPsbt = await _bdkWallet.signPsbt(
        payjoin.proposalPsbt!,
        wallet: wallet,
      );
      result = await _broadcastPsbt(
        payjoinId: payjoin.id,
        finalizedPsbt: finalizedPsbt,
        network: payjoinModel.isTestnet
            ? Network.bitcoinTestnet
            : Network.bitcoinMainnet,
      );
      log.info(
        'Payjoin proposal broadcasted for ${payjoin.logRef} '
        '(tx ${logSafeToken(result.txId)})',
      );
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
    } else {
      // Both the payjoin and the original-transaction fallback failed: mark
      //  the session terminally failed (modelled as expired, which
      //  SendCubit._watchPayjoin already surfaces as a broadcast failure)
      //  instead of leaving the send flow hanging on "coordinating" with no
      //  event ever arriving again.
      final failedModel = payjoinModel.copyWith(isExpired: true);
      await _localPayjoinDatasource.update(failedModel);
      _payjoinStreamController.add(failedModel.toEntity());
    }
  }

  Future<void> _processExpiredPayjoin(PayjoinModel payjoinModel) async {
    final payjoin = payjoinModel.toEntity();

    // TODO: Unfreeze the utxo used in the payjoin

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
      //  No proposal ever went out, so no broadcast watcher (armed only once
      //  a proposal is sent — see _watchForBroadcast's call sites) can exist
      //  for this session; stopping it here is a defensive no-op.
      //
      //  Deliberately do NOT persist the raw expired model first:
      //  tryBroadcastOriginalTransaction persists isCompleted itself on
      //  success. If the broadcast fails (e.g. no network at that exact
      //  moment), leaving the row unfinished means the next app start's
      //  resumePayjoinsOnStartup sees isExpiryTimePassed still true and
      //  retries the fallback — persisting isExpired here would instead
      //  permanently exclude it from onlyUnfinished and drop the retry.
      _stopWatching(payjoinModel.id);
      final result = await _broadcastOriginalTransaction(payjoin);
      _payjoinStreamController.add(result ?? payjoin);
    } else if (payjoin is PayjoinSender && payjoin.proposalPsbt == null) {
      // The sender never received a proposal before expiry (the receiver
      //  didn't respond), so fall back to broadcasting the original
      //  transaction — the payment must still go through. Guard on
      //  proposalPsbt == null: once a proposal arrived, _processPayjoinProposal
      //  owns finalizing/broadcasting the payjoin transaction (same inputs).
      //
      //  Emit only the terminal outcome: the completed result on success (so
      //  the send flow resolves to success), or the raw expired entity if the
      //  fallback broadcast itself failed (so listeners see a terminal state
      //  and don't hang on the "coordinating" screen). We deliberately do NOT
      //  emit the interim expired entity before the fallback, which would race
      //  the completed one on the stream.
      //
      //  Same reasoning as the receiver branch above for not persisting the
      //  expired flag up front: a failed broadcast must remain retryable on
      //  the next resume.
      _stopWatching(payjoinModel.id);
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
      //  Nothing left for us to retry from this side, so persist the expired
      //  marker now (unlike the two fallback branches above).
      await _localPayjoinDatasource.update(payjoinModel);
      _payjoinStreamController.add(payjoin);
    }
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
  }) {
    if (_broadcastWatchers.containsKey(payjoinId)) return;

    final subscription = _walletRepository().walletSyncFinishedStream
        .where((wallet) => wallet.id == walletId)
        .asyncMap((_) async {
          try {
            return await _walletTransactionRepository().getWalletTransaction(
              txId,
              walletId: walletId,
            );
          } catch (e) {
            log.warning('Payjoin broadcast watch lookup failed: $e');
            return null;
          }
        })
        .where((tx) => tx != null)
        .listen((_) => _onPayjoinTransactionSeen(payjoinId));

    _broadcastWatchers[payjoinId] = subscription;

    _scheduleBroadcastPoll(
      payjoinId: payjoinId,
      walletId: walletId,
      txId: txId,
      attempt: 0,
    );
  }

  /// Arms the next active broadcast poll for [_watchForBroadcast]: after an
  /// exponentially backed-off delay, forces a sync'd wallet-transaction
  /// lookup and either completes the session or reschedules itself.
  /// [_broadcastWatchers] is the single source of truth for "still watched":
  /// once _stopWatching removed the session (completed, fallback broadcast,
  /// or teardown), a pending poll callback becomes a no-op.
  void _scheduleBroadcastPoll({
    required String payjoinId,
    required String walletId,
    required String txId,
    required int attempt,
  }) {
    if (attempt >= broadcastPollMaxAttempts) return;

    var delay = broadcastPollInitialDelay * (1 << attempt.clamp(0, 30));
    if (delay > broadcastPollMaxDelay) delay = broadcastPollMaxDelay;

    _broadcastPollTimers[payjoinId] = Timer(delay, () async {
      if (!_broadcastWatchers.containsKey(payjoinId)) return;

      WalletTransaction? tx;
      try {
        tx = await _walletTransactionRepository().getWalletTransaction(
          txId,
          walletId: walletId,
          sync: true,
        );
      } catch (e) {
        log.warning('Payjoin broadcast poll failed: $e');
      }

      // Re-check: the session may have completed through the passive watcher
      // (or been torn down) while the sync'd lookup was in flight.
      if (!_broadcastWatchers.containsKey(payjoinId)) return;

      if (tx != null) {
        await _onPayjoinTransactionSeen(payjoinId);
      } else {
        _scheduleBroadcastPoll(
          payjoinId: payjoinId,
          walletId: walletId,
          txId: txId,
          attempt: attempt + 1,
        );
      }
    });
  }

  Future<void> _onPayjoinTransactionSeen(String payjoinId) async {
    // Stop first: the watch stream re-emits on every sync, and completion is
    // a one-shot side effect.
    _stopWatching(payjoinId);

    final model = await _localPayjoinDatasource.fetchReceiver(payjoinId);
    if (model == null || model.isCompleted) return;

    final completedModel = model.copyWith(isCompleted: true);
    await _localPayjoinDatasource.update(completedModel);
    if (completedModel.txId != null) {
      await _labelPayjoinTransaction(
        txId: completedModel.txId!,
        walletId: completedModel.walletId,
      );
    }
    _payjoinStreamController.add(completedModel.toEntity());
    log.info('Payjoin receiver completed on broadcast: $payjoinId');
  }

  /// Stops both the passive watcher and the active poll of a session.
  /// Synchronous on purpose: `StreamSubscription.cancel()` already guarantees
  /// no further events are delivered from the moment it is CALLED, so nothing
  /// here needs to block on its returned future (which only signals resource
  /// cleanup) — and awaiting it would make completion latency depend on the
  /// upstream stream's teardown.
  void _stopWatching(String payjoinId) {
    _broadcastPollTimers.remove(payjoinId)?.cancel();
    final subscription = _broadcastWatchers.remove(payjoinId);
    if (subscription != null) unawaited(subscription.cancel());
  }

  /// Whether a received payjoin [amountSat] falls below the configured
  /// [minAmountSat] threshold, i.e. the request should be declined as a
  /// payjoin (and the original transaction broadcast instead). A null amount
  /// (not yet known) is never treated as below-minimum. Pure and static so
  /// the anti-probing threshold decision is unit-testable in isolation.
  @visibleForTesting
  static bool isBelowPayjoinMinimum({
    required int? amountSat,
    required int minAmountSat,
  }) {
    return amountSat != null && amountSat < minAmountSat;
  }

  /// Runs [action], retrying up to [maxAttempts] times with a fixed [delay]
  /// when it fails with a transient relay error (all OHTTP relays momentarily
  /// unreachable). Non-transient errors are rethrown immediately so the
  /// caller's fallback still fires without waiting out the retries. Static so
  /// the retry policy is unit-testable without the repository's collaborators.
  ///
  /// Defaults sized against [PayjoinConstants.defaultExpireAfterSec] (1
  /// minute): this runs on the receiver AFTER its own poll already found the
  /// request, absorbing a blip while posting the proposal (a plain POST, not
  /// the long-poll — bounded by connectTimeout, not the 35s receiveTimeout,
  /// so a dead relay fails fast). Worst case with all 3 relays down on every
  /// attempt: maxAttempts × (3 relays × connectTimeout) + (maxAttempts - 1)
  /// × delay ≈ 2 × 30s + 1s = 61s — already at the whole 1-minute session
  /// budget, so these must stay small. The previous 3/2s (≈94s worst case)
  /// was sized for the old 5-minute expiry and would eat the receiver's
  /// entire budget on this retry alone under the new one.
  @visibleForTesting
  static Future<T> retryOnTransient<T>(
    Future<T> Function() action, {
    int maxAttempts = 2,
    Duration delay = const Duration(seconds: 1),
  }) async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await action();
      } on PayjoinNotFoundException catch (e) {
        if (attempt >= maxAttempts) rethrow;
        log.info(
          'Transient payjoin relay failure (attempt $attempt/$maxAttempts), '
          'retrying: $e',
        );
        await Future<void>.delayed(delay);
      }
    }
  }

  @override
  Future<void> resumePayjoinsOnStartup() async {
    final models = await _localPayjoinDatasource.fetchAll(onlyUnfinished: true);
    for (final model in models) {
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
          message: 'Failed to resume payjoin session ${model.logRef}',
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
      //  in limbo (neither payjoin nor fallback ever hits the chain). With
      //  the short 5-minute expiry this is now the common case, not an edge.
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
      }
    } else if (model is PayjoinSenderModel) {
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
    return _lock.synchronized(() async {
      final lockedUtxos = await getUtxosFrozenByOngoingPayjoins();
      final exposedRefs = await _exposedUtxoRefs();
      final inputPairs = filterAvailableUtxos(
        unspentUtxos,
        lockedUtxos,
        exposedRefs,
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

      final isMineSync = await _bdkWallet.createIsMineChecker(wallet: wallet);
      final signPsbtSync = await _bdkWallet.createPsbtSigner(wallet: wallet);
      final updatedModel = await _pdkPayjoinDatasource.proposePayjoin(
        receiverModel: freshModel,
        hasOwnedInputs: isMineSync,
        hasReceiverOutput: isMineSync,
        inputPairs: inputPairs,
        processPsbt: signPsbtSync,
      );

      await _localPayjoinDatasource.update(updatedModel);
      // Label the UTXO(s) we just exposed to the sender. If the payjoin never
      // completes, this lets a later proposal prefer re-contributing the same
      // already-exposed coin instead of burning a fresh one (BIP78's
      // "reuse the exposed UTXO" mitigation).
      await _labelExposedUtxos(
        candidates: inputPairs,
        proposalPsbt: updatedModel.proposalPsbt,
        walletId: payjoin.walletId,
      );
      return updatedModel.toEntity() as PayjoinReceiver;
    });
  }

  /// The `txid:vout` references of this wallet's UTXOs already exposed by a
  /// prior payjoin proposal, tagged with the payjoin system output label.
  /// Best-effort: a labels read failure degrades to "no preference".
  Future<Set<String>> _exposedUtxoRefs() async {
    final labels = await _labelsFacade().fetchAll();
    return labels
        .where(
          (l) =>
              l.type == LabelType.output &&
              l.label == LabelSystem.payjoin.label,
        )
        .map((l) => l.reference)
        .toSet();
  }

  /// Filters out locked UTXOs and orders the rest so already-exposed coins
  /// are preferred. Pure and static so it can be unit-tested without the
  /// repository's collaborators.
  @visibleForTesting
  static List<PayjoinInputPairModel> filterAvailableUtxos(
    List<WalletUtxoModel> unspent,
    List<({String txId, int vout})> locked,
    Set<String> exposedRefs,
  ) {
    final available =
        unspent
            .where(
              (u) => !locked.any((l) => l.txId == u.txId && l.vout == u.vout),
            )
            .whereType<BitcoinWalletUtxoModel>()
            .toList()
          // Prefer already-exposed UTXOs so we don't reveal a fresh one when
          // an earlier proposal already burned the privacy of this coin.
          ..sort((a, b) {
            final aExposed = exposedRefs.contains('${a.txId}:${a.vout}');
            final bExposed = exposedRefs.contains('${b.txId}:${b.vout}');
            if (aExposed == bExposed) return 0;
            return aExposed ? -1 : 1;
          });
    return available
        .map((u) => PayjoinInputPairModel.fromWalletUtxoModel(u))
        .toList();
  }

  /// Tags every candidate UTXO that ended up as an input of [proposalPsbt]
  /// (i.e. the coins the receiver actually contributed and thereby exposed)
  /// with the payjoin system output label. Best-effort and idempotent (the
  /// labels table dedupes on (label, reference)).
  Future<void> _labelExposedUtxos({
    required List<PayjoinInputPairModel> candidates,
    required String? proposalPsbt,
    required String walletId,
  }) async {
    if (proposalPsbt == null) return;
    try {
      final proposalTx = await BitcoinTx.fromPsbt(proposalPsbt);
      final proposalInputs = proposalTx.inputs
          .map((i) => '${i.txid}:${i.vout}')
          .toSet();
      final candidateRefs = candidates
          .map((c) => '${c.txId}:${c.vout}')
          .toSet();
      final exposed = proposalInputs.intersection(candidateRefs);
      for (final ref in exposed) {
        await _labelsFacade().store(
          NewLabel(
            type: LabelType.output,
            label: LabelSystem.payjoin.label,
            reference: ref,
            origin: walletId,
          ),
        );
      }
    } catch (e) {
      log.warning('Failed to label exposed payjoin UTXOs: $e');
    }
  }

  Future<PayjoinSender> _broadcastPsbt({
    required String payjoinId,
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

    // Update the local database with the completed payjoin
    final model = await _localPayjoinDatasource.fetchSender(payjoinId);
    if (model == null) {
      throw Exception('Payjoin sender not found');
    }
    final completedModel = model.copyWith(isCompleted: true);
    await _localPayjoinDatasource.update(completedModel);
    if (completedModel.txId != null) {
      await _labelPayjoinTransaction(
        txId: completedModel.txId!,
        walletId: completedModel.walletId,
      );
    }

    // Best-effort, non-blocking: see tryBroadcastOriginalTransaction's call
    // for why this can't wait on some unrelated sync to run.
    _syncWalletAfterBroadcast(completedModel.walletId);

    return completedModel.toEntity() as PayjoinSender;
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
  /// this repository's callers (tryBroadcastOriginalTransaction,
  /// _broadcastPsbt) already wrap their whole body in a try/catch for the
  /// broadcast itself, so a SYNCHRONOUS throw from `_walletRepository()` or
  /// `getWallet(...)` (as opposed to the future it returns rejecting) would
  /// otherwise be caught by that outer try/catch and misreported as the
  /// broadcast having failed, even though it already succeeded.
  void _syncWalletAfterBroadcast(String walletId) {
    unawaited(
      Future(
        () => _walletRepository().getWallet(walletId, sync: true),
      ).catchError((e) {
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
        'Failed to label payjoin transaction ${logSafeToken(txId)}',
      ),
    );
  }
}

class NoInputsToPayjoinException extends BullException {
  NoInputsToPayjoinException(super.message);
}
