import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bull_payjoin/src/data/payjoin_input_pair_model.dart';
import 'package:bull_payjoin/src/data/payjoin_model.dart';
import 'package:bull_payjoin/src/engine/bitcoin_tx.dart';
import 'package:bull_payjoin/src/engine/payjoin.dart' show Payjoin;
import 'package:bull_payjoin/src/engine/payjoin_constants.dart';
import 'package:bull_payjoin/src/engine/payjoin_engine_exception.dart';
import 'package:bull_payjoin/src/engine/payjoin_logger.dart' as logger;
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:payjoin/payjoin.dart';
import 'package:payjoin/http.dart' show fetchOhttpKeys;
import 'package:primitives/primitives.dart' show Outpoint;

/// Fetches the OHTTP key config published by [directoryUrl] through
/// [ohttpRelayUrl]. Matches the signature of `payjoin/http.dart`'s top-level
/// `fetchOhttpKeys`, which is the default implementation used in production;
/// tests can inject a fake to exercise the relay fallback logic offline.
typedef OhttpKeysFetcher =
    Future<OhttpKeys> Function({
      required String ohttpRelayUrl,
      required String directoryUrl,
    });

class PdkPayjoinDatasource {
  final String _payjoinDirectoryUrl;
  final Dio _dio;
  final logger.PayjoinLogger _log;
  final OhttpKeysFetcher _fetchOhttpKeys;
  final StreamController<PayjoinReceiverModel> _payjoinRequestedController;
  final StreamController<PayjoinSenderModel> _proposalSentController;
  final StreamController<PayjoinModel> _expiredController;

  // Per-session polling timers keyed by session id
  final Map<String, Timer> _receiverTimers = {};
  final Map<String, Timer> _senderTimers = {};

  // In-flight guards: Timer.periodic doesn't await its async callback, so a
  // slow poll (e.g. an unresponsive OHTTP relay) could otherwise overlap with
  // the next tick and process the same session twice — double-emitting the
  // request/proposal and cancelling the payjoin downstream.
  final Set<String> _receiverPollsInFlight = {};
  final Set<String> _senderPollsInFlight = {};

  bool _disposed = false;

  PdkPayjoinDatasource({
    this._payjoinDirectoryUrl = PayjoinConstants.directoryUrl,
    required this._dio,
    required this._log,
    OhttpKeysFetcher ohttpKeysFetcher = fetchOhttpKeys,
  }) : _fetchOhttpKeys = ohttpKeysFetcher,
       _payjoinRequestedController = StreamController.broadcast(),
       _proposalSentController = StreamController.broadcast(),
       _expiredController = StreamController.broadcast();

  Stream<PayjoinReceiverModel> get requestsForReceivers =>
      _payjoinRequestedController.stream;

  Stream<PayjoinSenderModel> get proposalsForSenders =>
      _proposalSentController.stream;

  Stream<PayjoinModel> get expiredPayjoins => _expiredController.stream;

  /// Stops the directory polling of one session — both the receiver
  /// request poll and the sender proposal poll, whichever exists for
  /// [payjoinId]. Called by the repository the moment a session resolves
  /// through a path the poll itself can't see (the plain-broadcast fallback
  /// landing on-chain): the poll only self-cancels on request/proposal
  /// found or expiry, so without this it kept firing until expiry and then
  /// raised a stale expired event for an already-completed session
  /// (observed live: a redundant second broadcast of the original
  /// transaction a minute after the session had already resolved).
  void stopPolling(String payjoinId) {
    _receiverTimers.remove(payjoinId)?.cancel();
    _senderTimers.remove(payjoinId)?.cancel();
  }

  /// Cancels every polling timer and closes the event streams. Individual
  /// poll timers self-cancel on success/expiry, but a session that never
  /// resolves (a relay permanently down) would otherwise leave a
  /// [Timer.periodic] firing forever plus three unclosed broadcast
  /// controllers. The production singleton lives for the whole app session,
  /// but tests (and any future teardown) need a clean exit; the repository's
  /// own dispose delegates here. Idempotent: a second call is a no-op (closing
  /// an already-closed controller would otherwise throw).
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final timer in _receiverTimers.values) {
      timer.cancel();
    }
    _receiverTimers.clear();
    for (final timer in _senderTimers.values) {
      timer.cancel();
    }
    _senderTimers.clear();
    _receiverPollsInFlight.clear();
    _senderPollsInFlight.clear();
    await _payjoinRequestedController.close();
    await _proposalSentController.close();
    await _expiredController.close();
  }

  Future<(OhttpKeys?, String?)> fetchOhttpKeyAndRelay({
    required String payjoinDirectory,
  }) async {
    for (final ohttpRelayUrl in PayjoinConstants.ohttpRelayUrls) {
      try {
        final ohttpKeys = await _fetchOhttpKeys(
          ohttpRelayUrl: ohttpRelayUrl,
          directoryUrl: payjoinDirectory,
        );
        return (ohttpKeys, ohttpRelayUrl);
      } catch (e) {
        _log.info('OHTTP key fetch failed');
        continue;
      }
    }
    return (null, null);
  }

  /// [amountSat] pins the amount inside the generated BIP21 URI.
  ///
  /// The receive flow leaves it null: the user types the amount after the
  /// session exists, and the URI is composed again on every keystroke. A caller
  /// that already knows the amount — the exchange buy flow, whose URI is handed
  /// to the backend once and can never be updated afterwards — passes it here
  /// so the PDK writes it into the URI itself, which avoids re-encoding a
  /// canonical URI by hand.
  Future<PayjoinReceiverModel> createReceiver({
    required String walletId,
    required String address,
    required bool isTestnet,
    required BigInt maxFeeRateSatPerVb,
    required int expireAfterSec,
    int? amountSat,
  }) async {
    try {
      final (ohttpKeys, ohttpRelay) = await fetchOhttpKeyAndRelay(
        payjoinDirectory: _payjoinDirectoryUrl,
      );

      if (ohttpRelay == null || ohttpKeys == null) {
        throw Exception('All OHTTP relays failed');
      }

      var receiverBuilder =
          ReceiverBuilder(
                address: address,
                directory: _payjoinDirectoryUrl,
                ohttpKeys: ohttpKeys,
              )
              .withExpiration(expirationSecs: expireAfterSec)
              .withMaxFeeRate(
                maxEffectiveFeeRateSatPerVb: maxFeeRateSatPerVb.toInt(),
              );

      if (amountSat != null) {
        receiverBuilder = receiverBuilder.withAmount(amountSats: amountSat);
      }

      final persister = InMemoryJsonReceiverSessionPersister();
      final initialized = receiverBuilder.build().save(persister: persister);
      final pjUri = initialized.pjUri().asString();
      // Derive the receiver ID from pjUri
      final id = sha256.convert(utf8.encode(pjUri)).toString().substring(0, 16);

      // Create and store the model to keep track of the payjoin session
      final model =
          PayjoinModel.receiver(
                id: id,
                address: address,
                isTestnet: isTestnet,
                receiver: persister.toJson(),
                walletId: walletId,
                pjUri: pjUri,
                maxFeeRateSatPerVb: maxFeeRateSatPerVb,
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                expireAfterSec: expireAfterSec,
              )
              as PayjoinReceiverModel;

      // Start listening for a payjoin request from the sender. This starts
      // polling before the repository persists `model` to the local DB
      // (PayjoinRepositoryImpl.createPayjoinReceiver awaits this call, then
      // stores the result) — benign today since the first tick is a full
      // directoryPollingInterval away, giving the upsert plenty of time, but
      // fragile enough to flag: don't start polling any earlier than this.
      startListeningForRequest(model);

      return model;
    } catch (e) {
      throw ReceiveCreationException(e.toString());
    }
  }

  Future<PayjoinSenderModel> createSender({
    required String walletId,
    required bool isTestnet,
    required String bip21,
    required String originalPsbt,
    required int amountSat,
    required double networkFeesSatPerVb,
    required Future<void> Function(PayjoinSenderModel model) persistBeforePost,
    int? expireAfterSec,
  }) async {
    final expirySec = expireAfterSec ?? PayjoinConstants.defaultExpireAfterSec;
    final senderLogRef = Payjoin.logRefForId(bip21);
    _log.info('[sender] creating $senderLogRef with expirySec=$expirySec');

    PjUri pjUri;
    final Uri parsedUri;
    try {
      parsedUri = Uri.parse(uri: bip21);
      pjUri = parsedUri.checkPjSupported();
    } catch (e) {
      throw NoValidPayjoinBip21Exception(e.toString());
    }

    var sendBuilder = SenderBuilder(psbt: originalPsbt, uri: pjUri);
    final persister = InMemoryJsonSenderSessionPersister();
    final minFeeRateSatPerKwu = (networkFeesSatPerVb * 250).round();
    WithReplyKey? withReplyKey;
    try {
      withReplyKey = sendBuilder
          .buildRecommended(minFeeRateSatPerKwu: minFeeRateSatPerKwu)
          .save(persister: persister);
    } catch (e) {
      throw SendCreationException(e.toString());
    }

    // Create the model with the data needed to keep track of the payjoin
    // session BEFORE publishing anything.
    final model =
        PayjoinModel.sender(
              uri: parsedUri.asString(),
              isTestnet: isTestnet,
              sender: persister.toJson(),
              walletId: walletId,
              originalPsbt: originalPsbt,
              originalTxId: (await BitcoinTx.fromPsbt(originalPsbt)).txid,
              amountSat: amountSat,
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              expireAfterSec: expirySec,
            )
            as PayjoinSenderModel;

    // Write-ahead: the caller persists the session row here, before the
    // signed original reaches the directory. A crash after the POST with no
    // durable row would leave a broadcastable payment with no fallback
    // watcher, no input reservation and no duplicate guard — a retry would
    // post a SECOND signed original for the same payment, potentially on
    // different inputs, and both could confirm. If this throws, nothing was
    // published and the creation aborts cleanly.
    await persistBeforePost(model);

    await postOriginalProposal(withReplyKey, persister);
    _log.info('[sender] original proposal posted for $senderLogRef');

    // The POST transitioned the session to PollingForProposal, but `model`
    // above still carries the PRE-POST session JSON (WithReplyKey) — that
    // pre-POST state is what the write-ahead needed, but the proposal poll
    // below replays `sender` and only proceeds on PollingForProposal.
    // Refresh the model to the post-POST state or the poll never advances.
    final postedModel = model.copyWith(sender: persister.toJson());

    // Start listening for a payjoin proposal from the receiver. The session
    // row is already persisted, so a proposal arriving immediately still
    // finds it.
    startListeningForProposal(postedModel);
    _log.info('[sender poll] started for $senderLogRef');

    return postedModel;
  }

  Future<void> postOriginalProposal(
    WithReplyKey withReplyKey,
    InMemoryJsonSenderSessionPersister persister,
  ) async {
    Object? lastError;
    var posted = false;
    for (final relay in PayjoinConstants.ohttpRelayUrls) {
      try {
        final reqCtx = withReplyKey.createV2PostRequest(ohttpRelay: relay);
        final body = await postBytes(
          _dio,
          reqCtx.request.url,
          reqCtx.request.body,
          reqCtx.request.contentType,
        );
        withReplyKey
            .processResponse(response: body, postCtx: reqCtx.ohttpCtx)
            .save(persister: persister);
        posted = true;
        break;
      } catch (e) {
        _log.info('Sender proposal relay failed');
        lastError = e;
        continue;
      }
    }
    if (!posted) {
      _log.warning(
        'Failed to post original PSBT to any OHTTP relay',
        error: lastError,
      );
      throw SendCreationException(
        'Failed to post original PSBT to any OHTTP relay: $lastError',
      );
    }
  }

  Future<PayjoinReceiverModel> proposePayjoin({
    required PayjoinReceiverModel receiverModel,
    required bool Function(Outpoint) ownsOutpoint,
    required bool Function(Uint8List) hasReceiverOutput,
    required List<PayjoinInputPairModel> inputPairs,
    required String Function(String) processPsbt,
  }) async {
    final persister = InMemoryJsonReceiverSessionPersister.fromJson(
      receiverModel.receiver,
      log: _log,
    );
    final state = replayReceiverEventLog(persister: persister).state();

    final result = await processReceiveSession(
      state: state,
      persister: persister,
      ownsOutpoint: ownsOutpoint,
      hasReceiverOutput: hasReceiverOutput,
      inputPairs: inputPairs,
      receiverModel: receiverModel,
      processPsbt: processPsbt,
    );

    // Update the model with the proposal psbt so it can be known a proposal has
    //  been sent
    final proposalPsbt = result.psbt;

    final updatedModel = receiverModel.copyWith(
      receiver: persister.toJson(),
      proposalPsbt: proposalPsbt,
      txId: (await BitcoinTx.fromPsbt(proposalPsbt)).txid,
    );

    _log.info(
      'Payjoin request processed and proposal sent for ${receiverModel.id}',
    );

    return updatedModel;
  }

  /// Formally cancels a receiver session that was declined below the
  /// configured minimum-receive-amount threshold (see
  /// PayjoinRepositoryImpl._processPayjoinRequest), and closes the
  /// underlying PDK session so it persists a terminal event.
  ///
  /// This replaces silently abandoning the session after broadcasting the
  /// original transaction out of band: without this, the PDK's own
  /// typestate machine never learns the session ended, so only our local
  /// DB flag (isAborted) stood between it and being replayed/resumed as if
  /// still pending. `cancel()` is available on every receive typestate that
  /// carries a fallback transaction (verified against the installed
  /// `payjoin` package's Dart bindings — `MaybeInputsOwned.cancel()` is one
  /// of them); calling it here transitions to `ReceiverPendingFallback`,
  /// whose `close()` persists the closing `SessionEvent` via the
  /// persister. The original transaction itself is still broadcast by the
  /// caller from the already-captured, already-validated
  /// [PayjoinReceiverModel.originalTxBytes] — this method only concludes
  /// the PDK-side state machine to match that outcome.
  ///
  /// Always called right after `_pollReceiverOnce` has persisted a session
  /// at exactly the `MaybeInputsOwned` typestate (where
  /// `originalTxBytes`/`amountSat` first become available) — any other
  /// state means the session already progressed past the point a
  /// below-minimum decline is possible, or is already resolved.
  String declineReceiverSession(PayjoinReceiverModel receiverModel) {
    final persister = InMemoryJsonReceiverSessionPersister.fromJson(
      receiverModel.receiver,
      log: _log,
    );
    final state = replayReceiverEventLog(persister: persister).state();
    if (state is! MaybeInputsOwnedReceiveSession) {
      throw StateError(
        'Cannot decline payjoin receiver ${receiverModel.id}: expected a '
        'MaybeInputsOwned session, got $state',
      );
    }

    final pendingFallback = state.inner.cancel().save(persister: persister);
    if (pendingFallback == null) {
      // The session was already terminal (e.g. a race with another decline
      // path) — nothing further to persist, but not an error either.
      _log.info(
        'Payjoin receiver ${receiverModel.id} was already resolved when '
        'declining below minimum',
      );
      return persister.toJson();
    }

    pendingFallback.close().save(persister: persister);
    return persister.toJson();
  }

  Future<({Monitor monitor, String psbt})> processReceiveSession({
    required ReceiveSession state,
    required InMemoryJsonReceiverSessionPersister persister,
    required bool Function(Outpoint) ownsOutpoint,
    required bool Function(Uint8List) hasReceiverOutput,
    required List<PayjoinInputPairModel> inputPairs,
    required PayjoinReceiverModel receiverModel,
    required String Function(String) processPsbt,
  }) async {
    switch (state) {
      case InitializedReceiveSession():
        throw StateError(
          'Original PSBT is retrieved in startListeningForRequest',
        );
      case UncheckedOriginalPayloadReceiveSession():
        return _checkProposal(
          state.inner,
          persister,
          ownsOutpoint,
          hasReceiverOutput,
          inputPairs,
          receiverModel,
          processPsbt,
        );
      case MaybeInputsOwnedReceiveSession():
        return _checkInputsNotOwned(
          state.inner,
          persister,
          ownsOutpoint,
          hasReceiverOutput,
          inputPairs,
          receiverModel,
          processPsbt,
        );
      case MaybeInputsSeenReceiveSession():
        return _checkNoInputsSeenBefore(
          state.inner,
          persister,
          hasReceiverOutput,
          inputPairs,
          receiverModel,
          processPsbt,
        );
      case OutputsUnknownReceiveSession():
        return _identifyReceiverOutputs(
          state.inner,
          persister,
          hasReceiverOutput,
          inputPairs,
          receiverModel,
          processPsbt,
        );
      case WantsOutputsReceiveSession():
        return _commitOutputs(
          state.inner,
          persister,
          inputPairs,
          receiverModel,
          processPsbt,
        );
      case WantsInputsReceiveSession():
        return _contributeInputs(
          state.inner,
          persister,
          inputPairs,
          receiverModel,
          processPsbt,
        );
      case WantsFeeRangeReceiveSession():
        return _applyFeeRange(
          state.inner,
          persister,
          receiverModel,
          processPsbt,
        );
      case ProvisionalProposalReceiveSession():
        return _finalizeProposal(state.inner, persister, processPsbt);
      case PayjoinProposalReceiveSession():
        return _sendPayjoinProposal(state.inner, persister);
      case HasReplyableExceptionReceiveSession():
        throw StateError('Receive session has a replyable exception');
      case MonitorReceiveSession():
        throw StateError(
          'Receive session is monitoring; proposal already sent',
        );
      case ClosedReceiveSession():
        throw StateError('Receive session is closed');
      default:
        throw StateError('Unexpected receive session state: $state');
    }
  }

  Future<({Monitor monitor, String psbt})> _checkProposal(
    UncheckedOriginalPayload inner,
    InMemoryJsonReceiverSessionPersister persister,
    bool Function(Outpoint) ownsOutpoint,
    bool Function(Uint8List) hasReceiverOutput,
    List<PayjoinInputPairModel> inputPairs,
    PayjoinReceiverModel receiverModel,
    String Function(String) processPsbt,
  ) async {
    final next = inner.assumeInteractiveReceiver().save(persister: persister);
    return _checkInputsNotOwned(
      next,
      persister,
      ownsOutpoint,
      hasReceiverOutput,
      inputPairs,
      receiverModel,
      processPsbt,
    );
  }

  Future<({Monitor monitor, String psbt})> _checkInputsNotOwned(
    MaybeInputsOwned inner,
    InMemoryJsonReceiverSessionPersister persister,
    bool Function(Outpoint) ownsOutpoint,
    bool Function(Uint8List) hasReceiverOutput,
    List<PayjoinInputPairModel> inputPairs,
    PayjoinReceiverModel receiverModel,
    String Function(String) processPsbt,
  ) async {
    final next = inner
        .checkInputsNotOwned(isOwned: _IsInputOwned(ownsOutpoint))
        .save(persister: persister);
    return _checkNoInputsSeenBefore(
      next,
      persister,
      hasReceiverOutput,
      inputPairs,
      receiverModel,
      processPsbt,
    );
  }

  Future<({Monitor monitor, String psbt})> _checkNoInputsSeenBefore(
    MaybeInputsSeen inner,
    InMemoryJsonReceiverSessionPersister persister,
    bool Function(Uint8List) hasReceiverOutput,
    List<PayjoinInputPairModel> inputPairs,
    PayjoinReceiverModel receiverModel,
    String Function(String) processPsbt,
  ) async {
    final next = inner
        .checkNoInputsSeenBefore(isKnown: _AssumeUnseen())
        .save(persister: persister);
    return _identifyReceiverOutputs(
      next,
      persister,
      hasReceiverOutput,
      inputPairs,
      receiverModel,
      processPsbt,
    );
  }

  Future<({Monitor monitor, String psbt})> _identifyReceiverOutputs(
    OutputsUnknown inner,
    InMemoryJsonReceiverSessionPersister persister,
    bool Function(Uint8List) hasReceiverOutput,
    List<PayjoinInputPairModel> inputPairs,
    PayjoinReceiverModel receiverModel,
    String Function(String) processPsbt,
  ) async {
    final next = inner
        .identifyReceiverOutputs(
          isReceiverOutput: _IsScriptOwned(hasReceiverOutput),
        )
        .save(persister: persister);
    return _commitOutputs(
      next,
      persister,
      inputPairs,
      receiverModel,
      processPsbt,
    );
  }

  Future<({Monitor monitor, String psbt})> _commitOutputs(
    WantsOutputs inner,
    InMemoryJsonReceiverSessionPersister persister,
    List<PayjoinInputPairModel> inputPairs,
    PayjoinReceiverModel receiverModel,
    String Function(String) processPsbt,
  ) async {
    final next = inner.commitOutputs().save(persister: persister);
    return _contributeInputs(
      next,
      persister,
      inputPairs,
      receiverModel,
      processPsbt,
    );
  }

  Future<({Monitor monitor, String psbt})> _contributeInputs(
    WantsInputs inner,
    InMemoryJsonReceiverSessionPersister persister,
    List<PayjoinInputPairModel> inputPairs,
    PayjoinReceiverModel receiverModel,
    String Function(String) processPsbt,
  ) async {
    final candidates = inputPairs.map(_buildInputPair).toList();
    InputPair? chosen;
    try {
      chosen = inner.tryPreservingPrivacy(candidateInputs: candidates);
    } catch (e) {
      // Include the PDK's own rejection reason (e.g. "no candidates
      // available for selection" when none of the wallet's UTXOs make a
      // privacy-preserving decoy for this payment) rather than a fixed
      // generic message, so callers/logs can tell this apart from a genuine
      // bug in candidate construction.
      throw StateError('No inputs available to contribute to payjoin: $e');
    }
    final next = inner
        .contributeInputs(replacementInputs: [chosen])
        .commitInputs()
        .save(persister: persister);
    return _applyFeeRange(next, persister, receiverModel, processPsbt);
  }

  Future<({Monitor monitor, String psbt})> _applyFeeRange(
    WantsFeeRange inner,
    InMemoryJsonReceiverSessionPersister persister,
    PayjoinReceiverModel receiverModel,
    String Function(String) processPsbt,
  ) async {
    final next = inner
        .applyFeeRange(
          minFeeRateSatPerVb: null,
          maxEffectiveFeeRateSatPerVb: receiverModel.maxFeeRateSatPerVb.toInt(),
        )
        .save(persister: persister);
    return _finalizeProposal(next, persister, processPsbt);
  }

  Future<({Monitor monitor, String psbt})> _finalizeProposal(
    ProvisionalProposal inner,
    InMemoryJsonReceiverSessionPersister persister,
    String Function(String) processPsbt,
  ) async {
    final next = inner
        .finalizeProposal(processPsbt: _ProcessPsbt(processPsbt))
        .save(persister: persister);
    return _sendPayjoinProposal(next, persister);
  }

  Future<({Monitor monitor, String psbt})> _sendPayjoinProposal(
    PayjoinProposal proposal,
    InMemoryJsonReceiverSessionPersister persister,
  ) async {
    Object? lastError;
    for (final relay in PayjoinConstants.ohttpRelayUrls) {
      try {
        final req = proposal.createPostRequest(ohttpRelay: relay);
        final body = await postBytes(
          _dio,
          req.request.url,
          req.request.body,
          req.request.contentType,
        );
        // Capture the proposal PSBT here, as it's not available on the monitor typestate.
        final psbt = proposal.psbt();
        final monitor = proposal
            .processResponse(body: body, ohttpContext: req.clientResponse)
            .save(persister: persister);
        return (monitor: monitor, psbt: psbt);
      } catch (e) {
        _log.info('Receiver proposal relay failed');
        lastError = e;
        continue;
      }
    }
    _log.warning(
      'Failed to post payjoin proposal to any OHTTP relay',
      error: lastError,
    );
    throw PayjoinNotFoundException(
      'Failed to post payjoin proposal: $lastError',
    );
  }

  InputPair _buildInputPair(PayjoinInputPairModel input) {
    // A missing value must never silently become 0: the witness UTXO amount
    // is committed in the segwit sighash, so signing over a wrong (zero)
    // amount produces an invalid signature. The failure would then surface
    // far away, as a generic broadcast rejection that silently cancels the
    // payjoin via the original-transaction fallback. Fail loudly instead.
    final value = input.value;
    if (value == null) {
      throw StateError(
        'Cannot build a payjoin input pair without a value for '
        '${input.txId}:${input.vout}',
      );
    }
    return InputPair(
      txin: TxIn(
        previousOutput: OutPoint(txid: input.txId, vout: input.vout),
        scriptSig: Uint8List.fromList(input.scriptSigRawOutputScript),
        sequence: input.sequence,
        witness: input.witness,
      ),
      psbtin: PsbtInput(
        witnessUtxo: TxOut(
          valueSat: value.toInt(),
          scriptPubkey: input.scriptPubkey,
        ),
        redeemScript: input.redeemScriptRawOutputScript.isEmpty
            ? null
            : Uint8List.fromList(input.redeemScriptRawOutputScript),
        witnessScript: input.witnessScriptRawOutputScript.isEmpty
            ? null
            : Uint8List.fromList(input.witnessScriptRawOutputScript),
      ),
      expectedWeight: null,
    );
  }

  void startListeningForRequest(PayjoinReceiverModel payjoin) {
    _receiverTimers[payjoin.id]?.cancel();
    _receiverTimers[payjoin.id] = Timer.periodic(
      const Duration(seconds: PayjoinConstants.directoryPollingInterval),
      (timer) => _pollReceiverOnce(payjoin, timer),
    );
  }

  void startListeningForProposal(PayjoinSenderModel payjoin) {
    _senderTimers[payjoin.id]?.cancel();
    _senderTimers[payjoin.id] = Timer.periodic(
      const Duration(seconds: PayjoinConstants.directoryPollingInterval),
      (timer) => _pollSenderOnce(payjoin, timer),
    );
  }

  Future<void> _pollReceiverOnce(
    PayjoinReceiverModel receiverModel,
    Timer timer,
  ) async {
    if (!_receiverPollsInFlight.add(receiverModel.id)) return;
    _log.info('Receiver poll started');
    try {
      // Local expiry backstop: don't rely solely on the PDK surfacing an
      // "expired" error — bound polling by the session's own expiry time.
      if (receiverModel.isExpiryTimePassed) {
        throw PayjoinExpiredException(
          'Payjoin receiver ${receiverModel.id} expiry time passed',
        );
      }
      final persister = InMemoryJsonReceiverSessionPersister.fromJson(
        receiverModel.receiver,
        log: _log,
      );
      final ReceiveSession state;
      try {
        state = replayReceiverEventLog(persister: persister).state();
      } on ReceiverReplayException catch (e) {
        if (_isExpiredString(e)) {
          throw PayjoinExpiredException('Payjoin receiver expired: $e');
        }
        rethrow;
      }
      if (state is! InitializedReceiveSession) return;

      final unchecked = await _getUncheckedOriginalPayload(
        state.inner,
        persister,
      );
      if (unchecked == null) {
        _log.info('Receiver request not ready');
        return;
      }

      final maybeInputsOwned = unchecked.assumeInteractiveReceiver().save(
        persister: persister,
      );
      final originalTxBytes = maybeInputsOwned.extractTxToScheduleBroadcast();
      final originalTx = await BitcoinTx.fromBytes(originalTxBytes);
      final amountSat = await originalTx.getAmountReceived(
        address: receiverModel.address,
        isTestnet: receiverModel.isTestnet,
      );
      _log.info('Receiver request found');
      final updatedModel = receiverModel.copyWith(
        receiver: persister.toJson(),
        originalTxBytes: originalTxBytes,
        originalTxId: originalTx.txid,
        amountSat: amountSat,
      );
      // Only stop polling and emit once all fallible work has succeeded: a
      // throw above leaves the timer armed so the next tick retries. Skip
      // the emit if this session's polling was stopped in the meantime.
      if (!timer.isActive) return;
      timer.cancel();
      _receiverTimers.remove(receiverModel.id);
      _payjoinRequestedController.add(updatedModel);
    } on PayjoinExpiredException catch (e) {
      _log.info('[receiver poll] expired for ${receiverModel.id}: $e');
      if (!timer.isActive) return;
      timer.cancel();
      _receiverTimers.remove(receiverModel.id);
      _expiredController.add(receiverModel.copyWith(isExpired: true));
    } catch (e) {
      _log.info('[receiver poll] ${receiverModel.id}: $e');
    } finally {
      _receiverPollsInFlight.remove(receiverModel.id);
    }
  }

  Future<void> _pollSenderOnce(
    PayjoinSenderModel senderModel,
    Timer timer,
  ) async {
    // logRef, never the raw id in log lines/exception messages: a sender id
    //  is the full BIP21 URI (address+amount+endpoint). The raw id is still
    //  used as the internal map key below, which never reaches a log.
    final senderLogRef = Payjoin.logRefForId(senderModel.id);
    if (!_senderPollsInFlight.add(senderModel.id)) return;
    _log.info('Sender poll started');
    try {
      // Local expiry backstop: don't rely solely on the PDK surfacing an
      // "expired" error — bound polling by the session's own expiry time.
      if (senderModel.isExpiryTimePassed) {
        throw PayjoinExpiredException(
          'Payjoin sender $senderLogRef expiry time passed',
        );
      }
      final persister = InMemoryJsonSenderSessionPersister.fromJson(
        senderModel.sender,
        log: _log,
      );
      final SendSession state;
      try {
        state = replaySenderEventLog(persister: persister).state();
      } on SenderReplayException catch (e) {
        if (_isExpiredString(e)) {
          throw PayjoinExpiredException('Payjoin sender expired: $e');
        }
        rethrow;
      }
      if (state is! PollingForProposalSendSession) return;

      final proposalPsbt = await _getProposalPsbt(state.inner, persister);
      if (proposalPsbt == null) return;

      _log.info('[sender poll] proposal found for $senderLogRef');
      final txId = (await BitcoinTx.fromPsbt(proposalPsbt)).txid;
      final updatedModel = senderModel.copyWith(
        sender: persister.toJson(),
        proposalPsbt: proposalPsbt,
        txId: txId,
      );
      // Only stop polling and emit once all fallible work has succeeded: a
      // throw above leaves the timer armed so the next tick retries. Skip
      // the emit if this session's polling was stopped in the meantime.
      if (!timer.isActive) return;
      timer.cancel();
      _senderTimers.remove(senderModel.id);
      _proposalSentController.add(updatedModel);
    } on PayjoinExpiredException catch (e) {
      _log.info('[sender poll] expired for $senderLogRef: $e');
      if (!timer.isActive) return;
      timer.cancel();
      _senderTimers.remove(senderModel.id);
      _expiredController.add(senderModel.copyWith(isExpired: true));
    } catch (e) {
      _log.info('[sender poll] $senderLogRef: $e');
    } finally {
      _senderPollsInFlight.remove(senderModel.id);
    }
  }

  Future<UncheckedOriginalPayload?> _getUncheckedOriginalPayload(
    Initialized initialized,
    InMemoryJsonReceiverSessionPersister persister,
  ) async {
    Object? lastError;
    for (final relay in PayjoinConstants.ohttpRelayUrls) {
      try {
        final poll = initialized.createPollRequest(ohttpRelay: relay);
        final body = await postBytes(
          _dio,
          poll.request.url,
          poll.request.body,
          poll.request.contentType,
        );
        final outcome = initialized
            .processResponse(body: body, ctx: poll.clientResponse)
            .save(persister: persister);
        if (outcome is StasisInitializedTransitionOutcome) return null;
        return (outcome as ProgressInitializedTransitionOutcome).inner;
      } on ReceiverException catch (e) {
        if (_isExpiredString(e)) {
          throw PayjoinExpiredException('Payjoin receiver expired: $e');
        }
        _log.info('Receiver poll request creation failed');
        lastError = e;
        continue;
      } catch (e) {
        _log.info('Receiver relay poll failed');
        lastError = e;
        continue;
      }
    }
    throw PayjoinNotFoundException('Failed to poll receiver: $lastError');
  }

  Future<String?> _getProposalPsbt(
    PollingForProposal polling,
    InMemoryJsonSenderSessionPersister persister,
  ) async {
    Object? lastError;
    for (final relay in PayjoinConstants.ohttpRelayUrls) {
      try {
        final poll = polling.createPollRequest(ohttpRelay: relay);
        final body = await postBytes(
          _dio,
          poll.request.url,
          poll.request.body,
          poll.request.contentType,
        );
        final outcome = polling
            .processResponse(response: body, ohttpCtx: poll.ohttpCtx)
            .save(persister: persister);
        if (outcome is StasisPollingForProposalTransitionOutcome) {
          return null;
        }
        return (outcome as ProgressPollingForProposalTransitionOutcome)
            .psbtBase64;
      } on CreateRequestException catch (e) {
        if (_isExpiredString(e)) {
          throw PayjoinExpiredException('Payjoin sender expired: $e');
        }
        _log.info('Sender poll request creation failed');
        lastError = e;
        continue;
      } catch (e) {
        _log.info('Sender relay poll failed');
        lastError = e;
        continue;
      }
    }
    throw PayjoinNotFoundException('Failed to poll sender: $lastError');
  }

  // "Expired" variants aren't exposed publicly as a distinct subtype.
  // Tighten to a typed check if the payjoin bindings start exposing variants.
  static bool _isExpiredString(Object error) =>
      error.toString().toLowerCase().contains('expired');

  /// Posts [body] to [url] via [dio] and returns the raw response bytes. The
  /// single choke point every OHTTP relay call funnels through — exposed for
  /// testing so the relay-loop functions' handling of a network failure
  /// (including a timeout from the Dio instance's configured
  /// connect/receiveTimeout, see PayjoinLocator) can be exercised directly,
  /// without needing a live relay or a signed PSBT/session fixture.
  @visibleForTesting
  static Future<Uint8List> postBytes(
    Dio dio,
    String url,
    Uint8List body,
    String contentType,
  ) async {
    final response = await dio.post<List<int>>(
      url,
      data: body,
      options: Options(
        headers: {'Content-Type': contentType},
        responseType: ResponseType.bytes,
      ),
    );
    return Uint8List.fromList(response.data ?? const []);
  }
}

class PayjoinNotFoundException extends PayjoinEngineException {
  PayjoinNotFoundException(super.message);
}

class ReceiveCreationException extends PayjoinEngineException {
  ReceiveCreationException(super.message);
}

class NoValidPayjoinBip21Exception extends PayjoinEngineException {
  NoValidPayjoinBip21Exception(super.message);
}

class PayjoinExpiredException extends PayjoinEngineException {
  PayjoinExpiredException(super.message);
}

class SendCreationException extends PayjoinEngineException {
  SendCreationException(super.message);
}

class _IsScriptOwned implements IsScriptOwned {
  final bool Function(Uint8List) _fn;
  _IsScriptOwned(this._fn);

  @override
  bool callback(Uint8List script) => _fn(script);
}

/// Bridges the crate's outpoint-keyed ownership callback to the wallet port.
///
/// The crate hands an OutPoint rather than a script precisely so the answer
/// cannot be steered by the sender's PSBT — see
/// PayjoinWalletPort.createOutpointOwnershipChecker.
class _IsInputOwned implements IsInputOwned {
  final bool Function(Outpoint) _fn;
  _IsInputOwned(this._fn);

  @override
  bool callback(OutPoint outpoint) =>
      _fn((txId: outpoint.txid, vout: outpoint.vout));
}

/// Assume the wallet has not seen the inputs since it is an interactive wallet
class _AssumeUnseen implements IsOutputKnown {
  @override
  bool callback(OutPoint outpoint) => false;
}

class _ProcessPsbt implements ProcessPsbt {
  final String Function(String) _sign;
  _ProcessPsbt(this._sign);

  @override
  String callback(String psbt) => _sign(psbt);
}

class InMemoryJsonReceiverSessionPersister
    implements JsonReceiverSessionPersister {
  final List<String> _events;
  bool _closed;

  InMemoryJsonReceiverSessionPersister([List<String>? initial])
    : _events = [...?initial],
      _closed = false;

  factory InMemoryJsonReceiverSessionPersister.fromJson(
    String? raw, {
    logger.PayjoinLogger log = logger.PayjoinLogger.silent,
  }) {
    return InMemoryJsonReceiverSessionPersister(_decodeEvents(raw, log));
  }

  List<String> get events => List.unmodifiable(_events);

  bool get isClosed => _closed;

  String toJson() => jsonEncode(_events);

  @override
  void save(String event) => _events.add(event);

  @override
  List<String> load() => List<String>.from(_events);

  @override
  void close() => _closed = true;
}

class InMemoryJsonSenderSessionPersister implements JsonSenderSessionPersister {
  final List<String> _events;
  bool _closed;

  InMemoryJsonSenderSessionPersister([List<String>? initial])
    : _events = [...?initial],
      _closed = false;

  factory InMemoryJsonSenderSessionPersister.fromJson(
    String? raw, {
    logger.PayjoinLogger log = logger.PayjoinLogger.silent,
  }) {
    return InMemoryJsonSenderSessionPersister(_decodeEvents(raw, log));
  }

  List<String> get events => List.unmodifiable(_events);

  bool get isClosed => _closed;

  String toJson() => jsonEncode(_events);

  @override
  void save(String event) => _events.add(event);

  @override
  List<String> load() => List<String>.from(_events);

  @override
  void close() => _closed = true;
}

List<String> _decodeEvents(String? raw, logger.PayjoinLogger log) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      // Eagerly validate every element here, inside the try/catch: `.cast()`
      // is a lazy view, so a list containing a non-string entry would slip
      // through uncaught and only throw later, deep inside
      // replayReceiverEventLog on every poll tick.
      return List<String>.from(decoded);
    }
    log.warning(
      'Persisted payjoin session event log is not a list; starting empty',
    );
  } catch (e) {
    log.warning(
      'Failed to decode persisted payjoin session event log: $e',
      error: e,
    );
  }
  return const [];
}
