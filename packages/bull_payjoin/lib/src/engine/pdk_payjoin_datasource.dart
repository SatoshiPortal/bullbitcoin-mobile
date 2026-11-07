import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:core' as core;
import 'dart:math';
import 'dart:typed_data';

import 'package:bull_payjoin/src/data/payjoin_input_pair_model.dart';
import 'package:bull_payjoin/src/data/payjoin_model.dart';
import 'package:bull_payjoin/src/domain/payjoin_ports.dart'
    show PayjoinLogCode, PayjoinLogRole;
import 'package:bull_payjoin/src/engine/bitcoin_tx.dart';
import 'package:bull_payjoin/src/engine/directory_poller.dart';
import 'package:bull_payjoin/src/engine/payjoin.dart' show Payjoin;
import 'package:bull_payjoin/src/engine/payjoin_constants.dart';
import 'package:bull_payjoin/src/engine/payjoin_engine_exception.dart';
import 'package:bull_payjoin/src/engine/payjoin_logger.dart' as logger;
import 'package:bull_payjoin/src/engine/payjoin_servers.dart';
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
/// [timeout] bounds each of the dependency's three HTTP stages.
typedef OhttpKeysFetcher =
    Future<OhttpKeys> Function({
      required String ohttpRelayUrl,
      required String directoryUrl,
      required Duration timeout,
    });

class PdkPayjoinDatasource {
  final List<core.Uri> _servers;
  final Random _random;
  final Dio _dio;
  final logger.PayjoinLogger _log;
  final OhttpKeysFetcher _fetchOhttpKeys;
  final StreamController<PayjoinReceiverModel> _payjoinRequestedController;
  final StreamController<PayjoinSenderModel> _proposalSentController;
  final StreamController<PayjoinModel> _expiredController;
  final DateTime Function() _now;

  // Monotonic clock the pollers measure poll durations with.
  final Stopwatch _clock = Stopwatch()..start();
  late final DirectoryPoller<PayjoinReceiverModel> _receiverPolls =
      DirectoryPoller(now: _now, elapsed: () => _clock.elapsed);
  late final DirectoryPoller<PayjoinSenderModel> _senderPolls = DirectoryPoller(
    now: _now,
    elapsed: () => _clock.elapsed,
  );

  // Servers whose last request failed, per role (keyed by the failure code):
  // one that stays down is warned about once, not on every poll.
  final Set<(PayjoinLogCode, String)> _failingServers = {};

  final Map<(PayjoinLogRole, String), PayjoinLogCode> _pollFailures = {};

  bool isPolling(String id) =>
      _receiverPolls.isPolling(id) || _senderPolls.isPolling(id);

  void _pollFailed(
    PayjoinModel model,
    PayjoinLogRole role,
    PayjoinLogCode code,
  ) {
    if (_pollFailures[(role, model.id)] == code) return;
    _pollFailures[(role, model.id)] = code;
    _log.warning(code: code, role: role, sessionRef: model.toEntity().logRef);
  }

  void _pollRecovered(PayjoinModel model, PayjoinLogRole role) {
    if (_pollFailures.remove((role, model.id)) != null) {
      _log.fine(
        code: PayjoinLogCode.pollRecovered,
        role: role,
        sessionRef: model.toEntity().logRef,
      );
    }
  }

  bool _disposed = false;

  PdkPayjoinDatasource({
    List<core.Uri>? servers,
    Random? random,
    required this._dio,
    required this._log,
    OhttpKeysFetcher ohttpKeysFetcher = fetchOhttpKeys,
    this._now = DateTime.now,
  }) : _servers = servers ?? PayjoinConstants.serverUrls,
       _random = random ?? Random.secure(),
       _fetchOhttpKeys = ohttpKeysFetcher,
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
    _pollFailures.removeWhere((key, _) => key.$2 == payjoinId);
    _receiverPolls.stop(payjoinId);
    _senderPolls.stop(payjoinId);
  }

  /// Cancels every polling timer and closes the event streams. Individual
  /// poll timers stop re-arming on success/expiry, but a session that never
  /// resolves (a relay permanently down) would otherwise keep re-arming its
  /// poll forever plus leave three unclosed broadcast controllers. The
  /// production singleton lives for the whole app session,
  /// but tests (and any future teardown) need a clean exit; the repository's
  /// own dispose delegates here. Idempotent: a second call is a no-op (closing
  /// an already-closed controller would otherwise throw).
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _pollFailures.clear();
    _receiverPolls.dispose();
    _senderPolls.dispose();
    await _payjoinRequestedController.close();
    await _proposalSentController.close();
    await _expiredController.close();
  }

  /// The longest one directory and relay pair may take to return keys, so
  /// several pairs fit in a discovery budget.
  static const _keyAttemptBudget = Duration(seconds: 10);

  /// Fetches the OHTTP keys of a random directory through its relays, moving
  /// to the next directory when none of them reaches it. Null when no
  /// directory can be reached. The total budget also bounds the wait for a plain receive QR.
  Future<({OhttpKeys keys, String directory})?> fetchDirectoryKeys({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'must be positive');
    }
    final elapsed = Stopwatch()..start();
    var stopped = false;

    void ensureActive() {
      if (stopped || _disposed || elapsed.elapsed >= timeout) {
        throw const _KeyDiscoveryStopped();
      }
    }

    Future<({OhttpKeys keys, String directory})?> discover() async {
      final directories = [..._servers]..shuffle(_random);
      for (final directory in directories) {
        try {
          ensureActive();
          final keys = await _throughRelays(
            directory,
            relaysOutsideDomainOf(directory, servers: _servers),
            (relay) async {
              ensureActive();
              final remaining = timeout - elapsed.elapsed;
              final attemptBudget = remaining < _keyAttemptBudget
                  ? remaining
                  : _keyAttemptBudget;
              if (attemptBudget <= Duration.zero) {
                throw const _KeyDiscoveryStopped();
              }
              final OhttpKeys keys;
              try {
                // fetchOhttpKeys times each of its three HTTP stages and closes
                // its client in finally; the outer deadline bounds the attempt
                // as a whole, so a relay that stalls leaves time for others.
                keys = await _fetchOhttpKeys(
                  ohttpRelayUrl: relay,
                  directoryUrl: directory.toString(),
                  timeout: attemptBudget,
                ).timeout(attemptBudget);
              } on Exception {
                ensureActive();
                rethrow;
              }
              ensureActive();
              return keys;
            },
          );
          return (keys: keys, directory: directory.toString());
        } on _KeyDiscoveryStopped {
          return null;
        } catch (_) {
          continue;
        }
      }
      return null;
    }

    try {
      return await discover().timeout(
        timeout,
        onTimeout: () {
          stopped = true;
          return null;
        },
      );
    } finally {
      stopped = true;
      elapsed.stop();
    }
  }

  /// Sends a session [request] through the relays allowed for [payjoinUri].
  Future<T> _throughSessionRelays<T>(
    String payjoinUri,
    Future<T> Function(String relay) request,
  ) async => _throughRelays(
    payjoinDirectoryOf(payjoinUri),
    allowedRelays(payjoinUri, servers: _servers),
    request,
  );

  /// Sends [request] to [directory] through each of [relays], a non-empty
  /// list, in a random order, and returns the first success. When every relay
  /// fails, the last failure is thrown and the payjoin step does not go
  /// through; an expired session stops at once.
  ///
  /// A relay is reported down only when another one reached the directory;
  /// when none does, the directory is.
  Future<T> _throughRelays<T>(
    core.Uri? directory,
    List<core.Uri> relays,
    Future<T> Function(String relay) request,
  ) async {
    final failed = <(core.Uri, Object)>[];
    for (final relay in [...relays]..shuffle(_random)) {
      try {
        final result = await request(relay.toString());
        for (final (failedRelay, error) in failed) {
          _reportServerFailed(
            failedRelay,
            PayjoinLogCode.relayUnreachable,
            error,
          );
        }
        _reportServerAnswered(relay, PayjoinLogCode.relayUnreachable);
        if (directory != null) {
          _reportServerAnswered(directory, PayjoinLogCode.directoryUnreachable);
        }
        return result;
      } on PayjoinExpiredException {
        rethrow;
      } on _KeyDiscoveryStopped {
        rethrow;
      } on CreateRequestException {
        // Local request validation says nothing about server availability.
        rethrow;
      } on ReceiverCreateRequestException {
        // Same on the receiver side, an expired session included.
        rethrow;
      } catch (e) {
        failed.add((relay, e));
      }
    }
    final (_, lastError) = failed.last;
    if (directory != null) {
      _reportServerFailed(
        directory,
        PayjoinLogCode.directoryUnreachable,
        lastError,
      );
    }
    throw lastError;
  }

  /// Warns the first time [server] fails, then keeps repeats to debug traces.
  void _reportServerFailed(
    core.Uri server,
    PayjoinLogCode failure,
    Object error,
  ) {
    if (_failingServers.add((failure, _hostKey(server)))) {
      _log.warning(code: failure, server: server, error: error);
    } else {}
  }

  /// Logs that [server] answered again in the role whose [failure] it had.
  void _reportServerAnswered(core.Uri server, PayjoinLogCode failure) {
    if (_failingServers.remove((failure, _hostKey(server)))) {
      _log.fine(code: PayjoinLogCode.serverRecovered, server: server);
    }
  }

  static String _hostKey(core.Uri url) => payjoinHostOf(url) ?? url.toString();

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
    bool isTrade = false,
  }) async {
    try {
      final directoryKeys = await fetchDirectoryKeys();
      if (directoryKeys == null) {
        throw Exception('No payjoin directory reachable');
      }

      var receiverBuilder =
          ReceiverBuilder(
                address: address,
                directory: directoryKeys.directory,
                ohttpKeys: directoryKeys.keys,
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
                isTrade: isTrade,
              )
              as PayjoinReceiverModel;

      // The directory poll is not started here: the engine arms it once the
      // session row is persisted and the policy re-check has passed, the way
      // payjoin-cli saves a session before driving it. A request found by a
      // poll must always land on a stored row.
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

    await postOriginalProposal(withReplyKey, persister, model);
    _log.fine(
      code: PayjoinLogCode.originalPosted,
      role: PayjoinLogRole.sender,
      sessionRef: senderLogRef,
    );

    // The POST transitioned the session to PollingForProposal, but `model`
    // above still carries the PRE-POST session JSON (WithReplyKey) — that
    // pre-POST state is what the write-ahead needed, but the proposal poll
    // below replays `sender` and only proceeds on PollingForProposal.
    // Refresh the model to the post-POST state or the poll never advances.
    // The proposal poll is not started here: the engine arms it once the
    // row carries this post-POST state, so a proposal found by the first
    // poll replays against a row that is already in PollingForProposal.
    return model.copyWith(sender: persister.toJson());
  }

  Future<void> postOriginalProposal(
    WithReplyKey withReplyKey,
    InMemoryJsonSenderSessionPersister persister,
    PayjoinSenderModel senderModel,
  ) async {
    try {
      await _throughSessionRelays(senderModel.uri, (relay) async {
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
      });
    } on CreateRequestException catch (e) {
      throw SendCreationException(
        e.isExpired()
            ? 'Payjoin session expired'
            : 'Could not create payjoin request',
      );
    } catch (e) {
      _log.warning(
        code: PayjoinLogCode.relayFailure,
        role: PayjoinLogRole.sender,
        error: e,
      );
      throw SendCreationException(
        'Failed to post original PSBT to any OHTTP relay: $e',
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

    _log.fine(
      code: PayjoinLogCode.proposalSent,
      role: PayjoinLogRole.receiver,
      sessionRef: receiverModel.id,
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
        return _finalizeProposal(
          state.inner,
          persister,
          receiverModel,
          processPsbt,
        );
      case PayjoinProposalReceiveSession():
        return _sendPayjoinProposal(state.inner, persister, receiverModel);
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
    return _finalizeProposal(next, persister, receiverModel, processPsbt);
  }

  Future<({Monitor monitor, String psbt})> _finalizeProposal(
    ProvisionalProposal inner,
    InMemoryJsonReceiverSessionPersister persister,
    PayjoinReceiverModel receiverModel,
    String Function(String) processPsbt,
  ) async {
    final next = inner
        .finalizeProposal(processPsbt: _ProcessPsbt(processPsbt))
        .save(persister: persister);
    return _sendPayjoinProposal(next, persister, receiverModel);
  }

  Future<({Monitor monitor, String psbt})> _sendPayjoinProposal(
    PayjoinProposal proposal,
    InMemoryJsonReceiverSessionPersister persister,
    PayjoinReceiverModel receiverModel,
  ) async {
    try {
      return await _throughSessionRelays(receiverModel.pjUri, (relay) async {
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
      });
    } on ReceiverCreateRequestException catch (e) {
      if (e.isExpired()) {
        throw PayjoinExpiredException('Payjoin receiver expired');
      }
      throw PayjoinNotFoundException(
        'Could not create payjoin proposal request',
      );
    } catch (e) {
      _log.warning(
        code: PayjoinLogCode.relayFailure,
        role: PayjoinLogRole.receiver,
        error: e,
      );
      throw PayjoinNotFoundException('Failed to post payjoin proposal: $e');
    }
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

  /// Starts polling the directory for the sender's request. A session that
  /// is already polled is left as it is; [stopPolling] it first to replace it.
  void startListeningForRequest(PayjoinReceiverModel payjoin) {
    _receiverPolls.start(
      id: payjoin.id,
      expiresAt: _expiryOf(payjoin),
      poll: (cancelToken) => _pollReceiverOnce(payjoin, cancelToken),
      onFound: (value) {
        _pollFailures.remove((PayjoinLogRole.receiver, payjoin.id));
        _payjoinRequestedController.add(value);
      },
      onExpired: () {
        _pollFailures.remove((PayjoinLogRole.receiver, payjoin.id));
        _expiredController.add(payjoin.copyWith(isExpired: true));
      },
    );
  }

  /// Starts polling the directory for the receiver's proposal. A session
  /// that is already polled is left as it is; [stopPolling] it first to
  /// replace it.
  void startListeningForProposal(PayjoinSenderModel payjoin) {
    _senderPolls.start(
      id: payjoin.id,
      expiresAt: _expiryOf(payjoin),
      poll: (cancelToken) => _pollSenderOnce(payjoin, cancelToken),
      onFound: (value) {
        _pollFailures.remove((PayjoinLogRole.sender, payjoin.id));
        _proposalSentController.add(value);
      },
      onExpired: () {
        _pollFailures.remove((PayjoinLogRole.sender, payjoin.id));
        _expiredController.add(payjoin.copyWith(isExpired: true));
      },
    );
  }

  static DateTime _expiryOf(PayjoinModel payjoin) =>
      DateTime.fromMillisecondsSinceEpoch(payjoin.expiresAt * 1000);

  /// One directory poll for [receiverModel]. Finds the sender's request, or
  /// says why it did not; never throws.
  Future<DirectoryPollResult<PayjoinReceiverModel>> _pollReceiverOnce(
    PayjoinReceiverModel receiverModel,
    CancelToken cancelToken,
  ) async {
    var stage = 'replay';
    var invalid = false;
    try {
      final persister = InMemoryJsonReceiverSessionPersister.fromJson(
        receiverModel.receiver,
        log: _log,
        onInvalid: () => invalid = true,
      );
      if (invalid) {
        _pollFailed(
          receiverModel,
          PayjoinLogRole.receiver,
          PayjoinLogCode.storageFailure,
        );
        return const DirectoryPollResult(DirectoryPollOutcome.failed);
      }
      final ReceiveSession state;
      try {
        state = replayReceiverEventLog(persister: persister).state();
      } on ReceiverReplayException catch (e) {
        if (_isExpiredString(e)) {
          throw PayjoinExpiredException('Payjoin receiver expired: $e');
        }
        rethrow;
      }
      if (state is! InitializedReceiveSession) {
        _pollFailures.remove((PayjoinLogRole.receiver, receiverModel.id));
        return const DirectoryPollResult(DirectoryPollOutcome.stale);
      }

      stage = 'transport';
      final unchecked = await _getUncheckedOriginalPayload(
        state.inner,
        persister,
        receiverModel,
        cancelToken,
      );
      stage = 'parse';
      if (unchecked == null) {
        _pollRecovered(receiverModel, PayjoinLogRole.receiver);
        return const DirectoryPollResult(DirectoryPollOutcome.empty);
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

      _pollRecovered(receiverModel, PayjoinLogRole.receiver);
      return DirectoryPollResult.found(
        receiverModel.copyWith(
          receiver: persister.toJson(),
          originalTxBytes: originalTxBytes,
          originalTxId: originalTx.txid,
          amountSat: amountSat,
        ),
      );
    } on PayjoinExpiredException {
      return const DirectoryPollResult(DirectoryPollOutcome.expired);
    } catch (_) {
      if (cancelToken.isCancelled) {
        return const DirectoryPollResult(DirectoryPollOutcome.expired);
      }

      if (stage != 'transport') {
        _pollFailed(
          receiverModel,
          PayjoinLogRole.receiver,
          stage == 'replay'
              ? PayjoinLogCode.pollReplayFailed
              : PayjoinLogCode.pollParseFailed,
        );
      }
      return const DirectoryPollResult(DirectoryPollOutcome.failed);
    }
  }

  /// One directory poll for [senderModel]. Finds the receiver's proposal, or
  /// says why it did not; never throws.
  Future<DirectoryPollResult<PayjoinSenderModel>> _pollSenderOnce(
    PayjoinSenderModel senderModel,
    CancelToken cancelToken,
  ) async {
    // logRef, never the raw id in log lines/exception messages: a sender id
    //  is the full BIP21 URI (address+amount+endpoint).

    var stage = 'replay';
    var invalid = false;
    try {
      final persister = InMemoryJsonSenderSessionPersister.fromJson(
        senderModel.sender,
        log: _log,
        onInvalid: () => invalid = true,
      );
      if (invalid) {
        _pollFailed(
          senderModel,
          PayjoinLogRole.sender,
          PayjoinLogCode.storageFailure,
        );
        return const DirectoryPollResult(DirectoryPollOutcome.failed);
      }
      final SendSession state;
      try {
        state = replaySenderEventLog(persister: persister).state();
      } on SenderReplayException catch (e) {
        if (_isExpiredString(e)) {
          throw PayjoinExpiredException('Payjoin sender expired: $e');
        }
        rethrow;
      }
      if (state is! PollingForProposalSendSession) {
        _pollFailures.remove((PayjoinLogRole.sender, senderModel.id));
        return const DirectoryPollResult(DirectoryPollOutcome.stale);
      }

      stage = 'transport';
      final proposalPsbt = await _getProposalPsbt(
        state.inner,
        persister,
        senderModel,
        cancelToken,
      );
      stage = 'parse';
      if (proposalPsbt == null) {
        _pollRecovered(senderModel, PayjoinLogRole.sender);
        return const DirectoryPollResult(DirectoryPollOutcome.empty);
      }

      final txId = (await BitcoinTx.fromPsbt(proposalPsbt)).txid;
      _pollRecovered(senderModel, PayjoinLogRole.sender);
      return DirectoryPollResult.found(
        senderModel.copyWith(
          sender: persister.toJson(),
          proposalPsbt: proposalPsbt,
          txId: txId,
        ),
      );
    } on PayjoinExpiredException {
      return const DirectoryPollResult(DirectoryPollOutcome.expired);
    } catch (_) {
      if (cancelToken.isCancelled) {
        return const DirectoryPollResult(DirectoryPollOutcome.expired);
      }

      if (stage != 'transport') {
        _pollFailed(
          senderModel,
          PayjoinLogRole.sender,
          stage == 'replay'
              ? PayjoinLogCode.pollReplayFailed
              : PayjoinLogCode.pollParseFailed,
        );
      }
      return const DirectoryPollResult(DirectoryPollOutcome.failed);
    }
  }

  Future<UncheckedOriginalPayload?> _getUncheckedOriginalPayload(
    Initialized initialized,
    InMemoryJsonReceiverSessionPersister persister,
    PayjoinReceiverModel receiverModel,
    CancelToken cancelToken,
  ) async {
    try {
      return await _throughSessionRelays(receiverModel.pjUri, (relay) async {
        try {
          final poll = initialized.createPollRequest(ohttpRelay: relay);
          final body = await postBytes(
            _dio,
            poll.request.url,
            poll.request.body,
            poll.request.contentType,
            cancelToken: cancelToken,
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
          rethrow;
        }
      });
    } on ReceiverCreateRequestException catch (e) {
      if (e.isExpired()) {
        throw PayjoinExpiredException('Payjoin receiver expired');
      }
      _pollFailed(
        receiverModel,
        PayjoinLogRole.receiver,
        PayjoinLogCode.pollRequestFailed,
      );
      throw PayjoinNotFoundException('Could not create poll request');
    } on PayjoinExpiredException {
      rethrow;
    } catch (e) {
      throw PayjoinNotFoundException('Failed to poll receiver: $e');
    }
  }

  Future<String?> _getProposalPsbt(
    PollingForProposal polling,
    InMemoryJsonSenderSessionPersister persister,
    PayjoinSenderModel senderModel,
    CancelToken cancelToken,
  ) async {
    try {
      return await _throughSessionRelays(senderModel.uri, (relay) async {
        try {
          final poll = polling.createPollRequest(ohttpRelay: relay);
          final body = await postBytes(
            _dio,
            poll.request.url,
            poll.request.body,
            poll.request.contentType,
            cancelToken: cancelToken,
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
          rethrow;
        }
      });
    } on PayjoinExpiredException {
      rethrow;
    } on CreateRequestException {
      _pollFailed(
        senderModel,
        PayjoinLogRole.sender,
        PayjoinLogCode.pollRequestFailed,
      );
      throw PayjoinNotFoundException('Could not create poll request');
    } catch (e) {
      throw PayjoinNotFoundException('Failed to poll sender: $e');
    }
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
    String contentType, {
    CancelToken? cancelToken,
  }) async {
    final response = await dio.post<List<int>>(
      url,
      data: body,
      options: Options(
        headers: {'Content-Type': contentType},
        responseType: ResponseType.bytes,
        // A relay must never redirect the client to the directory itself,
        // which would expose the client's IP outside the OHTTP tunnel.
        followRedirects: false,
      ),
      cancelToken: cancelToken,
    );
    return Uint8List.fromList(response.data ?? const []);
  }
}

final class _KeyDiscoveryStopped implements Exception {
  const _KeyDiscoveryStopped();
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
    void Function()? onInvalid,
  }) {
    return InMemoryJsonReceiverSessionPersister(
      _decodeEvents(raw, log, onInvalid),
    );
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
    void Function()? onInvalid,
  }) {
    return InMemoryJsonSenderSessionPersister(
      _decodeEvents(raw, log, onInvalid),
    );
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

List<String> _decodeEvents(
  String? raw,
  logger.PayjoinLogger log, [
  void Function()? onInvalid,
]) {
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
  } catch (_) {
    // Saved event contents never reach diagnostics.
  }
  if (onInvalid != null) {
    onInvalid();
  } else {
    log.warning(code: PayjoinLogCode.storageFailure);
  }
  return const [];
}
